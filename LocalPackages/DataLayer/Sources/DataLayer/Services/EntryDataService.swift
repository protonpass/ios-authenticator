//
// EntryDataService.swift
// Proton Authenticator - Created on 28/02/2025.
// Copyright (c) 2025 Proton Technologies AG
//
// This file is part of Proton Authenticator.
//
// Proton Authenticator is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Proton Authenticator is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Proton Authenticator. If not, see https://www.gnu.org/licenses/.

import AuthenticatorRustCore
import Combine
import CoreData
import Foundation
import Models

@MainActor
public protocol EntryDataServiceProtocol: Sendable, Observable {
    var dataState: DataState<[EntryUiModel]> { get }

    func getEntry(from uri: String) async throws -> Entry
    // periphery:ignore
    func insertAndRefreshEntry(from uri: String) async throws
    func insertAndRefreshEntry(from params: EntryParameters) async throws
    func updateAndRefreshEntry(for entryId: String, with params: EntryParameters) async throws
    func insertAndRefresh(entry: Entry) async throws
    func loadEntries()
    func delete(_ entry: EntryUiModel) async throws
    func reorderItem(from currentPosition: Int, to newPosition: Int) async throws

    func fullRefresh() async throws

    // MARK: - Expose repo functionalities to not have to inject several data source in view models

    func getTotpParams(entry: Entry) throws -> TotpParams
    func exportEntries() throws -> String
    func importEntries(from source: TwofaImportSource) async throws -> Int
    func stopTotpGenerator()
    func startTotpGenerator()
}

public final class CurrentTimeProviderImpl: MobileCurrentTimeProvider {
    public init() {}

    public func now() -> UInt64 {
        UInt64(Date.now.timeIntervalSince1970)
    }
}

@MainActor
@Observable
public final class EntryDataService: EntryDataServiceProtocol {
    // MARK: - Properties

    public private(set) var dataState: DataState<[EntryUiModel]> = .loading

    @ObservationIgnored
    private let repository: any EntryRepositoryProtocol
    @ObservationIgnored
    private let importService: any ImportingServicing
    @ObservationIgnored
    private var task: Task<Void, Never>?
    @ObservationIgnored
    private var cancellables = Set<AnyCancellable>()
    @ObservationIgnored
    private var totpGenerator: any TotpGeneratorProtocol
    @ObservationIgnored
    private var entryUpdateTask: Task<Void, Never>?
    @ObservationIgnored
    private let totpIssuerMapper: any TOTPIssuerMapperServicing
    @ObservationIgnored
    private var fullRefreshTask: Task<Void, Never>?

    @ObservationIgnored
    private let syncOperation: any SyncOperationCheckerProtocol

    @ObservationIgnored
    private let logger: LoggerProtocol

    // MARK: - Init

    public init(repository: any EntryRepositoryProtocol,
                importService: any ImportingServicing,
                totpGenerator: any TotpGeneratorProtocol,
                totpIssuerMapper: any TOTPIssuerMapperServicing,
                logger: any LoggerProtocol,
                syncOperation: any SyncOperationCheckerProtocol = SyncOperationChecker()) {
        self.repository = repository
        self.importService = importService
        self.totpGenerator = totpGenerator
        self.totpIssuerMapper = totpIssuerMapper
        self.logger = logger
        self.syncOperation = syncOperation
        setUp()
    }

    private func setUp() {
        loadEntries()

        NotificationCenter.default.publisher(for: NSPersistentCloudKitContainer.eventChangedNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                let key = NSPersistentCloudKitContainer.eventNotificationUserInfoKey
                guard let self,
                      let event = notification.userInfo?[key] as? NSPersistentCloudKitContainer.Event,
                      event.endDate != nil, event.type == .import else { return }
                log(.debug, "Received notification of updates from iCloud Database")
                loadEntries()
            }
            .store(in: &cancellables)

        totpGenerator.currentCode
            .receive(on: DispatchQueue.main)
            .compactMap(\.self)
            .sink { [weak self] codes in
                guard let self else { return }
                updateCodes(newCodes: codes)
            }
            .store(in: &cancellables)
    }
}

public extension EntryDataService {
    func getEntry(from uri: String) async throws -> Entry {
        try await repository.entry(for: uri)
    }

    func insertAndRefresh(entry: Entry) async throws {
        log(.debug, "Inserting and refreshing entry with ID: \(entry.id)")
        try await save(entry)
    }

    // periphery:ignore
    func insertAndRefreshEntry(from uri: String) async throws {
        log(.info, "Inserting entry from URI: \(uri)")
        let entry = try await repository.entry(for: uri)
        try await save(entry)
        log(.debug, "Inserted entry from URI: \(uri)")
    }

    func insertAndRefreshEntry(from params: EntryParameters) async throws {
        log(.debug, "Inserting and refreshing entry from parameters: \(params)")
        let entry = try createEntry(with: params)
        try await save(entry)
    }

    func updateAndRefreshEntry(for entryId: String, with params: EntryParameters) async throws {
        log(.debug, "Updating and refreshing entry with ID: \(entryId) and params: \(params)")

        var entry = try createEntry(with: params)
        entry.id = entryId
        try await updateEntry(entry: entry, remotePush: true)
    }

    func delete(_ entry: EntryUiModel) async throws {
        log(.debug, "Deleting entry with ID: \(entry.id)")
        try await deleteEntry(with: entry.id, remotePush: true)
    }

    func reorderItem(from currentPosition: Int, to newPosition: Int) async throws {
        log(.debug, "Reordering item from position \(currentPosition) to \(newPosition)")
        guard let entry = dataState.data?[currentPosition] else {
            return
        }
        guard var data = dataState.data else {
            return
        }
        data.remove(at: currentPosition)
        data.insert(entry, at: newPosition)
        data = updateOrder(data: data)
        try await repository.updateOrder(entryIdMoved: entry.id, data, remotePush: true)
        updateData(data)
    }

    func loadEntries() {
        log(.debug, "Loading entries")
        task?.cancel()
        task = Task { [weak self] in
            guard let self else { return }
            do {
                if Task.isCancelled { return }
                let entriesStates = try await repository.getAllLocalEntries()
                if Task.isCancelled { return }
                let entries = try await generateUIEntries(from: entriesStates.decodedEntries)
                log(.debug, "Loaded \(entries.count) entries.")
                updateData(entries)
            } catch {
                log(.error, "Failed to load entries: \(error)")
                if let data = dataState.data, !data.isEmpty { return }
                dataState = .failed(error)
            }
        }
    }

    func updateData(_ entries: [EntryUiModel]) {
        log(.debug, "Updating data with \(entries.count) entries")
        dataState = .loaded(entries)
        totpUpdate(entries.map(\.entry))
    }

    func fullRefresh() async throws {
        log(.debug, "Full BE refresh")
        await task?.value

        fullRefreshTask?.cancel()
        fullRefreshTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await repository.fetchAndSaveRemoteKeys()

                let remoteOrderedEntries = try await repository.fetchRemoteEntries()

                if Task.isCancelled { return }
                let entriesStates = try await repository.getAllLocalEntries()

                guard entriesStates.decodedEntries != remoteOrderedEntries else {
                    return
                }

//                print("woot sync local entries: \(entriesStates.decodedEntries) remote: \(remoteOrderedEntries)")
                try await syncOperation(remoteOrderedEntries: remoteOrderedEntries, entriesStates: entriesStates)

                // swiftlint:disable:next todo
                // TODO: reorder if remote and local not same remote should be
                let newOrderedItems = try await reorderItems()
                let entries = try await generateUIEntries(from: newOrderedItems)
//                log(.debug, "Loaded \(entries.count) entries.")
                updateData(entries)
            } catch {
                log(.error, "Failed to fullRefresh: \(error)")
            }
        }
    }
}

// MARK: - Rust exposure

public extension EntryDataService {
    func getTotpParams(entry: Entry) throws -> TotpParams {
        log(.debug, "Getting TOTP parameters for entry with ID: \(entry.id)")
        return try repository.getTotpParams(entry: entry)
    }

    func exportEntries() throws -> String {
        log(.debug, "Exporting entries")
        guard let data = dataState.data else {
            throw AuthError.generic(.exportEmptyData)
        }
        let entries = data.map(\.entry)
        return try repository.export(entries: entries)
    }

    nonisolated func importEntries(from source: TwofaImportSource) async throws -> Int {
        await log(.debug, "Importing entries from source: \(source)")
        let results = try importService.importEntries(from: source)
        var data: [EntryUiModel] = await dataState.data ?? []
        let filteredResults = results.entries
            .filter { entry in !data.contains(where: { $0.entry.isDuplicate(of: entry) }) }
        let codes = try repository.generateCodes(entries: filteredResults)

        var index = data.count
        var uiEntries: [EntryUiModel] = []
        for code in codes {
            let issuerInfo = totpIssuerMapper.lookup(issuer: code.entry.issuer)
            uiEntries.append(EntryUiModel(entry: code.entry,
                                          code: code,
                                          order: index,
                                          syncState: .unsynced,
                                          issuerInfo: issuerInfo))
            index += 1
        }
        try await repository.save(uiEntries, remotePush: true)

        data.append(contentsOf: uiEntries)
        await MainActor.run {
            updateData(data)
        }
        return uiEntries.count
    }

    func stopTotpGenerator() {
        log(.debug, "Stopping TOTP generator")
        entryUpdateTask?.cancel()
        entryUpdateTask = nil
        Task {
            await totpGenerator.stopUpdating()
        }
    }

    func startTotpGenerator() {
        entryUpdateTask?.cancel()
        log(.info, "Starting TOTP generator")
        entryUpdateTask = Task { [weak self] in
            guard let self, let data = dataState.data?.map(\.entry) else { return }
            do {
                try await totpGenerator.totpUpdate(data)
                log(.debug, "TOTP generator started for \(data.count) entries")
            } catch {
                log(.error, "Failed to start TOTP generator: \(error)")
            }
        }
    }
}

private extension EntryDataService {
    func totpUpdate(_ entries: [Entry]) {
        entryUpdateTask?.cancel()
        log(.debug, "Updating TOTP for \(entries.count) entries")
        entryUpdateTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await totpGenerator.totpUpdate(entries)
            } catch {
                log(.error, "Failed TOTP update: \(error)")
            }
        }
    }

    func save(_ entry: Entry, syncState: EntrySyncState = .unsynced, remotePush: Bool = true) async throws {
        var data: [EntryUiModel] = dataState.data ?? []

//        guard !data.contains(where: { $0.entry.isDuplicate(of: entry) }) else {
//            log(.warning, "Attempted to save duplicate entry")
//            throw AuthError.generic(.duplicatedEntry)
//        }
//
        let codes = try repository.generateCodes(entries: [entry])
        guard let code = codes.first else {
            log(.error, "Missing generated codes: expected 1, got \(codes.count)")
            throw AuthError.generic(.missingGeneratedCodes(codeCount: codes.count,
                                                           entryCount: 1))
        }
        let order = data.count
        let issuerInfo = totpIssuerMapper.lookup(issuer: code.entry.issuer)
        let entryUI = EntryUiModel(entry: code.entry,
                                   code: code,
                                   order: order,
                                   syncState: syncState,
                                   issuerInfo: issuerInfo)
        try await repository.save(entryUI, remotePush: remotePush)

        data.append(entryUI)
        updateData(data)
        log(.debug, "Saved entry \(entryUI.id)")
    }

    func updateEntry(entry: Entry, remotePush: Bool) async throws {
        try await repository.update(entry, remotePush: remotePush)

        var data: [EntryUiModel] = dataState.data ?? []
        if let index = data.firstIndex(where: { $0.id == entry.id }) {
            data[index] = data[index].copy(newEntry: entry)
        }
        updateData(data)
    }

    func deleteEntry(with id: String, remotePush: Bool) async throws {
        guard var data = dataState.data else {
            return
        }
        log(.info, "Deleting entry with ID: \(id)")
        try await repository.remove(id, remotePush: remotePush)
        data = data.filter { $0.entry.id != id }
        data = updateOrder(data: data)
        try await repository.updateOrder(entryIdMoved: nil, data, remotePush: false)
        updateData(data)
        log(.debug, "Deleted entry with ID: \(id)")
    }

    func createEntry(with params: EntryParameters) throws -> Entry {
        switch params {
        case let .steam(params):
            log(.debug, "Creating Steam entry")
            return try repository.createSteamEntry(params: params)
        case let .totp(params):
            log(.debug, "Creating TOTP entry")
            return try repository.createTotpEntry(params: params)
        }
    }

    func generateUIEntries(from entries: [OrderedEntry]) async throws -> [EntryUiModel] {
        log(.debug, "Generating UI entries from \(entries.count) entries")
        let codes = try repository.generateCodes(entries: entries.map(\.entry))
        guard codes.count == entries.count else {
            log(.warning, "Mismatch between codes and entries: \(codes.count) codes, \(entries.count) entries")
            throw AuthError.generic(.missingGeneratedCodes(codeCount: codes.count,
                                                           entryCount: entries.count))
        }

        var results = [EntryUiModel]()
        for (index, code) in codes.enumerated() {
            guard let entry = entries[safeIndex: index] else {
                log(.error, "Missing entry for generated code at index \(index)")
                throw AuthError.generic(.missingEntryForGeneratedCode)
            }
            let issuerInfo = totpIssuerMapper.lookup(issuer: code.entry.issuer)
            results.append(.init(entry: entry.entry,
                                 code: code,
                                 order: index,
                                 syncState: entry.syncState,
                                 issuerInfo: issuerInfo))
        }

        return results
    }

    func updateOrder(data: [EntryUiModel]?) -> [EntryUiModel] {
        log(.debug, "Updating entry order")
        guard var data else {
            log(.warning, "No data available to update order")
            return []
        }

        for (index, entry) in data.enumerated() where entry.order != index {
            data[index] = entry.updateOrder(index)
        }
        return data
    }

    func log(_ level: LogLevel, _ message: String, function: String = #function, line: Int = #line) {
        logger.log(level, category: .data, message, function: function, line: line)
    }

    func updateCodes(newCodes: [Code]) {
        guard let entries = dataState.data else { return }
        let entryUiModels = newCodes.compactMap { newCode -> EntryUiModel? in
            guard let entry = entries.first(where: { $0.id == newCode.entry.id }) else { return nil }
            return entry.updateCode(newCode)
        }

        dataState = .loaded(entryUiModels)
    }

    func syncOperation(remoteOrderedEntries: [OrderedEntry], entriesStates: [EntryState]) async throws {
        let operations = try syncOperation
            .calculateOperations(remote: remoteOrderedEntries.toRemoteEntries,
                                 local: entriesStates.toLocalEntries)

        for operation in operations {
            switch operation.operation {
            case .upsert:
                try await save(operation.entry.toEntry, syncState: .synced, remotePush: false)
            case .deleteLocal:
                try await deleteEntry(with: operation.entry.id, remotePush: false)
            case .deleteLocalAndRemote:
                try await deleteEntry(with: operation.entry.id, remotePush: true)
            case .push:
                try await save(operation.entry.toEntry, syncState: .unsynced, remotePush: true)
            case .conflict:
                guard let remoteEntry = remoteOrderedEntries.first(where: { operation.entry.id == $0.id }),
                      let localEntry = entriesStates.decodedEntries
                      .first(where: { operation.entry.id == $0.id }) else {
                    return
                }
                if remoteEntry.modifiedTime > localEntry.modifiedTime {
                    try await updateEntry(entry: remoteEntry.entry, remotePush: false)
                } else {
                    try await updateEntry(entry: localEntry.entry, remotePush: true)
                }
            }
        }
    }

    func reorderItems( /* localItems: [OrderedEntry], remoteItems: [OrderedEntry] */ ) async throws
        -> [OrderedEntry] {
        async let remoteOrderedEntries = repository.fetchRemoteEntries()
        async let localEntriesFetch = repository.getAllLocalEntries()

        let (remoteEntries, localEntries) = try await (remoteOrderedEntries, localEntriesFetch)

        // Step 1: Merge items by `id` with conflict resolution
        var currentItems = [String: OrderedEntry]()
        for item in localEntries.decodedEntries + remoteEntries {
            if let existing = currentItems[item.id], item.order != existing.order {
                // Resolve by most recently modified
                currentItems[item.id] = item.modifiedTime > existing.modifiedTime ? item : existing
            } else {
                currentItems[item.id] = item
            }
        }

        // Step 2: Sort items by existing `order`and last modified time (if they have the same order)
        let mergedAndOrderedItems = currentItems.values
            .sorted { $0.order < $1.order && $0.modifiedTime < $1.modifiedTime }
            .enumerated()
            .map { index, item in
                item.updateOrder(index)
            }

//        //TODO: save new order if changes detected need to implement

        return mergedAndOrderedItems
    }
}

extension [EntryState] {
    var decodedEntries: [OrderedEntry] {
        compactMap(\.entryAndSyncState)
    }
}
