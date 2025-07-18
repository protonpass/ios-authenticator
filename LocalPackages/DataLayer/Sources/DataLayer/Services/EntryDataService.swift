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
import ProtonCoreNetworking
import ProtonCoreServices

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

    @_spi(QA)
    func deleteAll() async throws

    // MARK: - Expose repo functionalities to not have to inject several data source in view models

    func getTotpParams(entry: Entry) throws -> TotpParams
    func exportEntries() throws -> String
    func importEntries(from sources: [TwofaImportSource]) async throws -> Int
    func stopTotpGenerator()
    func startTotpGenerator()

    func unsyncAllEntries() async throws
}

public extension EntryDataServiceProtocol {
    func importEntries(from source: TwofaImportSource) async throws -> Int {
        try await importEntries(from: [source])
    }
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
        let oldEntry = data[index]
        data[index] = oldEntry.copy(newEntry: entry)

        try await repository.completeUpdate(entry: data[index].orderedEntry, oldEntry: oldEntry.orderedEntry)

        updateData(data)
    }

    func delete(_ entry: EntryUiModel) async throws {
        guard let currentData = dataState.data else { return }

        log(.debug, "Deleting entry with ID: \(entry.id)")

        try await repository.completeRemoves(entries: [entry.orderedEntry])

        let filteredData = currentData.filter { $0.orderedEntry.id != entry.id }

        // Only reorder items whose order changes
        let (updatedOrderedEntries, changedEntries) = updateOrderAndExtractChanges(uiEntries: filteredData)

        if !changedEntries.isEmpty {
            try await repository.localReorder(changedEntries)
        } else {
            log(.debug, "No order changes required")
        }

        updateData(updatedOrderedEntries)
        log(.debug, "Deleted entry with ID: \(entry.id)")
    }

    func reorderItem(from currentPosition: Int, to newPosition: Int) async throws {
        log(.debug, "Reordering item from position \(currentPosition) to \(newPosition)")
        guard currentPosition != newPosition, var entries = dataState.data else {
            return
        }

        entries.move(from: currentPosition, to: newPosition)

        // Only reorder items whose order changes
        let (updatedOrderedEntries, changedEntries) = updateOrderAndExtractChanges(uiEntries: entries)
        try await repository.completeReorder(entries: changedEntries)
        updateData(updatedOrderedEntries)
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
            try await repository.fetchRemoteEncryptionKeyOrPushLocalKey()

            let remoteOrderedEntries = try await repository.fetchAllRemoteEntries()
            if Task.isCancelled { return }
            let entriesStates = try await repository.getAllLocalEntries()

            _ = try await syncOperation(remoteOrderedEntries: remoteOrderedEntries,
                                        entriesStates: entriesStates)

            let newOrderedItems = try await reorderItems()
            let entries = try await generateUIEntries(from: newOrderedItems)
            updateData(entries)
        } catch {
            log(.error, "Failed to fullRefresh: \(error.localizedDescription)")
            if let coreError = error as? ResponseError,
               coreError.bestShotAtReasonableErrorCode == APIErrorCode.potentiallyBlocked {
                log(.info, "No internet connection or Proton is blocked. Loading local entries.")
                try await loadEntries()
                return
            }

            if let data = dataState.data, !data.isEmpty {
                return
            }
            dataState = .failed(error)
        }
    }

    func unsyncAllEntries() async throws {
        log(.debug, "Unsync all entries")
        do {
            try await repository.unsyncAllEntries()
            let entriesStates = try await repository.getAllLocalEntries()

            let entries = try await generateUIEntries(from: entriesStates.decodedEntries)
            updateData(entries)
        } catch {
            log(.error, "Failed to Unsync all entries: \(error.localizedDescription)")
            throw error
        }
    }

    func deleteAll() async throws {
        log(.debug, "Deleting all entries")
        do {
            let localEntries = try await repository.getAllLocalEncryptedEntries()

            let entryIdsToRemove = localEntries.map(\.id)
            let keyIdsToReset = localEntries.map(\.keyId)

            try await repository.localRemoves(entryIdsToRemove)
            try await repository.reset(keyIds: keyIdsToReset)

            await repository.resetRemoteKeys()

            if let remoteEntries = try? await repository.fetchAllRemoteEntries() {
                _ = try? await repository.remoteDeletes(remoteEntryIds: remoteEntries.compactMap(\.remoteId))
            }
            try await loadEntries()
        } catch {
            log(.error, "Failed to delete all entries: \(error.localizedDescription)")
            throw error
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

    nonisolated func importEntries(from sources: [TwofaImportSource]) async throws -> Int {
        let results = try importService.importEntries(from: sources)
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

    func updateOrderAndExtractChanges(uiEntries: [EntryUiModel]?)
        -> (updated: [EntryUiModel], changedEntries: [OrderedEntry]) {
        guard var uiEntries else {
            log(.warning, "No data available to update order")
            return ([], [])
        }

        var changed: [OrderedEntry] = []

        for (index, uiEntry) in uiEntries.enumerated() where uiEntry.orderedEntry.order != index {
            let updated = uiEntry.updateOrder(index)
            uiEntries[index] = updated
            changed.append(updated.orderedEntry)
        }

        return (uiEntries, changed)
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

    func syncOperation(remoteOrderedEntries: [OrderedEntry], entriesStates: [EntryState]) async throws -> Bool {
        let operations = try syncOperation
            .calculateOperations(remote: remoteOrderedEntries.toRemoteEntries,
                                 local: entriesStates.toLocalEntries)

        var itemsToPushToRemote: [OrderedEntry] = []
        var itemsToFullyDelete: [OrderedEntry] = []
        var itemsToUpsertLocally: [OrderedEntry] = []
        var itemIdsToDeleteLocally: [String] = []
        var itemsToUpdateRemotely: [OrderedEntry] = []

        for operation in operations {
            switch operation.operation {
            case .upsert:
                if let orderedEntry = remoteOrderedEntries
                    .getFirstOrderedEntry(for: operation.entry.id) {
                    let syncedEntry = orderedEntry.updateSyncState(.synced)
                    itemsToUpsertLocally.append(syncedEntry)
                }
            case .deleteLocal:
                itemIdsToDeleteLocally.append(operation.entry.id)
            case .deleteLocalAndRemote:
                if let orderedEntry = entriesStates.getFirstOrderedEntry(for: operation.entry.id) {
                    itemsToFullyDelete.append(orderedEntry)
                }
            case .push:
                if let orderedEntry = entriesStates.getFirstOrderedEntry(for: operation.entry.id) {
                    if operation.remoteId != nil, let revision = operation.revision {
                        itemsToUpdateRemotely.append(orderedEntry.updateRevision(Int(revision)))
                    } else {
                        itemsToPushToRemote.append(orderedEntry)
                    }
                }
            }
        }

        async let localEntriesFetch: () = repository.localUpsert(itemsToUpsertLocally)
        async let remoteSave = repository.remoteSave(entries: itemsToPushToRemote)
        async let remoteUpdate = repository.remoteUpdates(entries: itemsToUpdateRemotely)
        async let localRemove: () = repository.localRemoves(itemIdsToDeleteLocally)
        async let fullyRemove: () = repository.completeRemoves(entries: itemsToFullyDelete)

        _ = try await (localEntriesFetch, remoteSave, remoteUpdate, localRemove, fullyRemove)

        return !operations.isEmpty
    }

    @MainActor
    func reorderItems() async throws -> [OrderedEntry] {
        async let remoteOrderedEntries = repository.fetchAllRemoteEntries()
        async let localEntriesFetch = repository.getAllLocalEntries()

        let (remoteEntries, localEntries) = try await (remoteOrderedEntries, localEntriesFetch)

        guard remoteEntries.map(\.id) != localEntries.decodedEntries.map(\.id) else {
            return localEntries.decodedEntries
        }

        return try await performReordering(remoteEntries: remoteEntries, localEntries: localEntries.decodedEntries)
    }

    @MainActor
    func performReordering(remoteEntries: [OrderedEntry],
                           localEntries: [OrderedEntry]) async throws -> [OrderedEntry] {
        var mergedItems = [String: OrderedEntry]()

        // Track all items
        let allItems = localEntries + remoteEntries

        for item in allItems {
            if let existing = mergedItems[item.id] {
                // Conflict resolution: prefer most recently modified
                if item.modifiedTime > existing.modifiedTime {
                    mergedItems[item.id] = item
                }
            } else {
                mergedItems[item.id] = item
            }
        }

        let sortedItems = mergedItems.values.sorted { item1, item2 in
            if item1.order != item2.order {
                return item1.order < item2.order
            }
            return item1.modifiedTime > item2.modifiedTime
        }

        let mergedOrderedItems = sortedItems.enumerated().map { index, item in
            item.updateOrder(index)
        }

        var itemsToUpdate: [OrderedEntry] = []

        for newOrderedItem in mergedOrderedItems {
            let newOrder = newOrderedItem.order
            let itemId = newOrderedItem.id

            var needsUpdate = false

            // Check if local version needs updating
            if let localItem = localEntries.first(where: { $0.id == itemId }),
               localItem.order != newOrder {
                needsUpdate = true
            }

            // Check if remote version needs updating
            if let remoteItem = remoteEntries.first(where: { $0.id == itemId }),
               remoteItem.order != newOrder {
                needsUpdate = true
            }

            if needsUpdate {
                itemsToUpdate.append(newOrderedItem)
            }
        }

        if !itemsToUpdate.isEmpty {
            try await repository.completeReorder(entries: itemsToUpdate)
        }

        return mergedOrderedItems
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
