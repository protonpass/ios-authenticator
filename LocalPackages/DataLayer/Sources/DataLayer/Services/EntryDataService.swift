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
import CommonUtilities
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
    func loadEntries() async throws
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
    private var cancellables = Set<AnyCancellable>()
    @ObservationIgnored
    private var totpGenerator: any TotpGeneratorProtocol
    @ObservationIgnored
    private var entryUpdateTask: Task<Void, Never>?
    @ObservationIgnored
    private let totpIssuerMapper: any TOTPIssuerMapperServicing

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
        totpGenerator.currentCodes
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
        if Task.isCancelled { return }
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
        var data: [EntryUiModel] = dataState.data ?? []
        guard let index = data.firstIndex(where: { $0.id == entry.id }) else {
            return
        }
        data[index] = data[index].copy(newEntry: entry)
        try await repository.completeUpdate(entry: data[index].orderedEntry)
//        var data: [EntryUiModel] = dataState.data ?? []
//        if let index = data.firstIndex(where: { $0.id == entry.id }) {
//            data[index] = data[index].copy(newEntry: entry)
//        }
        updateData(data)
    }

    func delete(_ entry: EntryUiModel) async throws {
        guard var data = dataState.data else {
            return
        }
        log(.debug, "Deleting entry with ID: \(entry.id)")

        try await repository.completeRemove(entry: entry.orderedEntry)

        data = data.filter { $0.orderedEntry.id != entry.id }
        data = updateOrder(uiEntries: data)
        try await repository.localReorder(data.map(\.orderedEntry))
        updateData(data)
        log(.debug, "Deleted entry with ID: \(entry.id)")
    }

    func reorderItem(from currentPosition: Int, to newPosition: Int) async throws {
        log(.debug, "Reordering item from position \(currentPosition) to \(newPosition)")
        guard currentPosition != newPosition else {
            return
        }
        guard var entryUiModels = dataState.data else {
            return
        }
        entryUiModels.move(from: currentPosition, to: newPosition)
        entryUiModels = updateOrder(uiEntries: entryUiModels)
        try await repository.completeReorder(entries: entryUiModels.map(\.orderedEntry))
        updateData(entryUiModels)
    }

    func loadEntries() async throws {
        log(.debug, "Loading entries")
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

    func updateData(_ entries: [EntryUiModel]) {
        log(.debug, "Updating data with \(entries.count) entries")
        startUpdatingTotpCode(entries.map(\.orderedEntry.entry))
        dataState = .loaded(entries)
    }

    func fullRefresh() async throws {
        log(.debug, "Full BE refresh")
        do {
            await repository.fetchRemoteEncryptionKeyOrPushLocalKey()

            let remoteOrderedEntries = try await repository.fetchAllRemoteEntries()
            if Task.isCancelled { return }
            let entriesStates = try await repository.getAllLocalEntries()

            _ = try await syncOperation(remoteOrderedEntries: remoteOrderedEntries, entriesStates: entriesStates)

            let newOrderedItems = try await reorderItems()
            let entries = try await generateUIEntries(from: newOrderedItems)
            updateData(entries)
        } catch {
            log(.error, "Failed to fullRefresh: \(error.localizedDescription)")
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
        let entries = data.map(\.orderedEntry)
        return try repository.export(entries: entries.map(\.entry))
    }

    nonisolated func importEntries(from source: TwofaImportSource) async throws -> Int {
        await log(.debug, "Importing entries from source: \(source)")
        let results = try importService.importEntries(from: source)
        var data: [EntryUiModel] = await dataState.data ?? []
        let filteredResults = results.entries
            .filter { entry in !data.contains(where: { $0.orderedEntry.entry.isDuplicate(of: entry) }) }
        let codes = try repository.generateCodes(entries: filteredResults)

        var index = data.count
        var uiEntries: [EntryUiModel] = []
        for code in codes {
            let issuerInfo = totpIssuerMapper.lookup(issuer: code.entry.issuer)
            let orderEntry = OrderedEntry(entry: code.entry,
                                          keyId: nil,
                                          remoteId: nil,
                                          order: index,
                                          modifiedTime: Date.currentTimestamp,
                                          revision: 0,
                                          contentFormatVersion: AppConstants.ContentFormatVersion.entry)
            uiEntries.append(EntryUiModel(orderedEntry: orderEntry,
                                          code: code,
                                          issuerInfo: issuerInfo))
            index += 1
        }

        _ = try await repository.completeSave(entries: uiEntries.map(\.orderedEntry))

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
        guard let entries = dataState.data?.map(\.orderedEntry.entry) else { return }

        log(.info, "Starting TOTP generator")
        startUpdatingTotpCode(entries)
//        entryUpdateTask?.cancel()
//        entryUpdateTask = Task { [weak self] in
//            do {
//                try await totpGenerator.startTotpCodeUpdate(data)
//                log(.debug, "TOTP generator started for \(data.count) entries")
//            } catch {
//                log(.error, "Failed to start TOTP generator: \(error)")
//            }
//        }
    }
}

private extension EntryDataService {
    func startUpdatingTotpCode(_ entries: [Entry]) {
        log(.debug, "Starting Updating TOTP codes for \(entries.count) entries")

        entryUpdateTask?.cancel()
        entryUpdateTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await totpGenerator.startTotpCodeUpdate(entries)
                log(.debug, "TOTP code generator started for \(entries.count) entries")
            } catch {
                log(.error, "Failed to start TOTP generator: \(error)")
            }
        }
    }

    func save(_ entry: Entry,
              remoteId: String? = nil) async throws {
        var data: [EntryUiModel] = dataState.data ?? []

        let codes = try repository.generateCodes(entries: [entry])
        guard let code = codes.first else {
            log(.error, "Missing generated codes: expected 1, got \(codes.count)")
            throw AuthError.generic(.missingGeneratedCodes(codeCount: codes.count,
                                                           entryCount: 1))
        }
        let order = data.count
        let issuerInfo = totpIssuerMapper.lookup(issuer: code.entry.issuer)
        let orderEntry = OrderedEntry(entry: code.entry,
                                      keyId: nil,
                                      remoteId: remoteId,
                                      order: order,
                                      modifiedTime: Date.currentTimestamp,
                                      revision: 0,
                                      contentFormatVersion: AppConstants.ContentFormatVersion.entry)
        var entryUI = EntryUiModel(orderedEntry: orderEntry,
                                   code: code,
                                   issuerInfo: issuerInfo)
        let remoteResults = try await repository.completeSave(entries: [entryUI.orderedEntry])

        if let remoteResult = remoteResults?.first {
            entryUI = entryUI.updateRemoteInfos(remoteResult.entryID)
        }

        data.append(entryUI)
        updateData(data)
        log(.debug, "Saved entry \(entryUI.id)")
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
        let entriesData = entries.map(\.entry)
        let codes = try repository.generateCodes(entries: entriesData)
        try await totpGenerator.startTotpCodeUpdate(entriesData)
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
            results.append(.init(orderedEntry: entry,
                                 code: code,
                                 issuerInfo: issuerInfo))
        }

        return results
    }

    func updateOrder(uiEntries: [EntryUiModel]?) -> [EntryUiModel] {
        log(.debug, "Updating entry order")
        guard var uiEntries else {
            log(.warning, "No data available to update order")
            return []
        }

        for (index, uiEntry) in uiEntries.enumerated() where uiEntry.orderedEntry.order != index {
            uiEntries[index] = uiEntry.updateOrder(index)
        }
        return uiEntries
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

    // swiftlint:disable:next cyclomatic_complexity
    func syncOperation(remoteOrderedEntries: [OrderedEntry], entriesStates: [EntryState]) async throws -> Bool {
        let operations = try syncOperation
            .calculateOperations(remote: remoteOrderedEntries.toRemoteEntries,
                                 local: entriesStates.toLocalEntries)

        for operation in operations {
            switch operation.operation {
            case .upsert:
                if let orderedEntry = remoteOrderedEntries
                    .getFirstOrderedEntry(for: operation.entry.id) {
                    let syncedEntry = orderedEntry.updateSyncState(.synced)
                    try await repository.localUpsert(syncedEntry)
                }
            case .deleteLocal:
                try await repository.localRemove(operation.entry.id)
            case .deleteLocalAndRemote:
                if let orderedEntry = entriesStates.getFirstOrderedEntry(for: operation.entry.id) {
                    try await repository.completeRemove(entry: orderedEntry)
                }
            case .push:
                if let orderedEntry = entriesStates.getFirstOrderedEntry(for: operation.entry.id) {
                    _ = try await repository.remoteSave(entries: [orderedEntry])
                }
            case .conflict:
                if let remoteEntry = remoteOrderedEntries.getFirstOrderedEntry(for: operation.entry.id),
                   let localEntry = entriesStates.getFirstOrderedEntry(for: operation.entry.id) {
                    let latestRevision = getLatestRevision(for: remoteEntry, and: localEntry)
                    if remoteEntry.modifiedTime > localEntry.modifiedTime {
                        _ = try await repository.localUpdate(remoteEntry)
                    } else {
                        let updatedRevision = localEntry.updateRevision(latestRevision)
                        _ = try await repository.remoteUpdate(entry: updatedRevision)
                    }
                }
            }
        }

        return !operations.isEmpty
    }

    func reorderItems() async throws -> [OrderedEntry] {
        async let remoteOrderedEntries = repository.fetchAllRemoteEntries()
        async let localEntriesFetch = repository.getAllLocalEntries()

        let (remoteEntries, localEntries) = try await (remoteOrderedEntries, localEntriesFetch)

        guard remoteEntries.map(\.id) != localEntries.decodedEntries.map(\.id) else {
            return localEntries.decodedEntries
        }

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
            .sorted {
                if $0.order != $1.order {
                    return $0.order < $1.order
                }
                return $0.modifiedTime > $1.modifiedTime
            }
            .enumerated()
            .map { index, item in
                item.updateOrder(index)
            }

        try await repository.completeReorder(entries: mergedAndOrderedItems)
        return mergedAndOrderedItems
    }

    func getLatestRevision(for lhs: OrderedEntry, and rhs: OrderedEntry) -> Int {
        max(lhs.revision, rhs.revision)
    }
}

extension [EntryState] {
    var decodedEntries: [OrderedEntry] {
        compactMap(\.entry)
    }

    func getFirstOrderedEntry(for entryId: String) -> OrderedEntry? {
        decodedEntries.getFirstOrderedEntry(for: entryId)
    }
}

extension [OrderedEntry] {
    func getFirstOrderedEntry(for entryId: String) -> OrderedEntry? {
        self.first { $0.entry.id == entryId }
    }
}
