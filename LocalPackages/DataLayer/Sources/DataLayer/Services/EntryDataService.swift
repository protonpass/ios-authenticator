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

// swiftlint:disable file_length

@MainActor
public protocol EntryDataServiceProtocol: Sendable, Observable {
    var dataState: DataState<[EntryUiModel]> { get }
    var hasNonDecryptableEntries: Bool { get }

    func getEntry(from uri: String) async throws -> Entry
    func insertAndRefreshEntry(from uri: String) async throws
    func insertAndRefreshEntry(from params: EntryParameters) async throws
    func updateAndRefreshEntry(for entryId: String, with params: EntryParameters) async throws
    func insertAndRefresh(entry: Entry) async throws
    func loadEntries() async throws
    func delete(_ entry: EntryUiModel) async throws
    func reorderItem(from currentPosition: Int, to newPosition: Int) async throws

    func fullRefresh() async throws
    func backUpEntries()

    func deleteAllEntries() async throws

    // MARK: - Expose repo functionalities to not have to inject several data source in view models

    func getTotpParams(entry: Entry) throws -> TotpParams
    func exportEntries(password: String?) throws -> String
    func importEntries(from sources: [TwofaImportSource]) async throws -> Int
    func stopTotpGenerator()
    func startTotpGenerator()
    func unsyncAllEntries() async throws
}

public extension EntryDataServiceProtocol {
    func exportEntries(password: String? = nil) throws -> String {
        try exportEntries(password: password)
    }
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
    public private(set) var hasNonDecryptableEntries = false

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
    private var fullRefreshTask: Task<Void, Error>?
    @ObservationIgnored
    private var loadTask: Task<Void, Error>?
    @ObservationIgnored
    private let totpIssuerMapper: any TOTPIssuerMapperServicing
    @ObservationIgnored
    private let reachabilityManager: any ReachabilityServicing
    @ObservationIgnored
    private var backUpManager: any BackUpServicing
    @ObservationIgnored
    private let syncOperation: any SyncOperationCheckerProtocol
    @ObservationIgnored
    private let logger: LoggerProtocol
    @ObservationIgnored
    private let settings: SettingsServicing
    @ObservationIgnored
    private let keychainService: KeychainServicing
    @ObservationIgnored
    private var savingEntryIds: Set<String> = []

    // MARK: - Init

    public init(repository: any EntryRepositoryProtocol,
                importService: any ImportingServicing,
                totpGenerator: any TotpGeneratorProtocol,
                totpIssuerMapper: any TOTPIssuerMapperServicing,
                logger: any LoggerProtocol,
                reachabilityManager: any ReachabilityServicing,
                backUpManager: any BackUpServicing,
                settings: any SettingsServicing,
                keychainService: any KeychainServicing,
                syncOperation: any SyncOperationCheckerProtocol = SyncOperationChecker()) {
        self.repository = repository
        self.importService = importService
        self.totpGenerator = totpGenerator
        self.totpIssuerMapper = totpIssuerMapper
        self.logger = logger
        self.reachabilityManager = reachabilityManager
        self.backUpManager = backUpManager
        self.syncOperation = syncOperation
        self.keychainService = keychainService
        self.settings = settings
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

    func insertAndRefreshEntry(from uri: String) async throws {
        if Task.isCancelled { return }
        log(.info, "Inserting entry from URI")
        let entry = try await repository.entry(for: uri)
        try await save(entry)
        log(.debug, "Inserted entry from URI")
    }

    func insertAndRefreshEntry(from params: EntryParameters) async throws {
        log(.debug, "Inserting and refreshing entry")
        let entry = try createEntry(with: params)
        try await save(entry)
    }

    func updateAndRefreshEntry(for entryId: String, with params: EntryParameters) async throws {
        guard !savingEntryIds.contains(entryId) else {
            log(.warning, "Entry \(entryId) update already in progress, skipping")
            return
        }
        savingEntryIds.insert(entryId)
        defer { savingEntryIds.remove(entryId) }

        log(.debug, "Updating and refreshing entry with ID: \(entryId)")

        var entry = try createEntry(with: params)
        entry.id = entryId
        var data: [EntryUiModel] = dataState.data ?? []
        guard let index = data.firstIndex(where: { $0.id == entry.id }) else {
            return
        }
        let oldEntry = data[index]
        let newEntry = oldEntry.copy(newEntry: entry)

        try await repository.completeUpdate(entry: newEntry.orderedEntry, oldEntry: oldEntry.orderedEntry)

        data[index] = newEntry
        updateData(data)
        backUpEntries()
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
        backUpEntries()
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
        backUpEntries()
    }

    func loadEntries() async throws {
        if let existingTask = loadTask {
            log(.debug, "Loading entries already in progress, joining existing task")
            try await existingTask.value
            return
        }

        let task = Task {
            try await performLoadingEntries()
        }

        loadTask = task
        defer { loadTask = nil }

        try await task.value
    }

    func updateData(_ entries: [EntryUiModel]) {
        let deduplicated = entries.deduplicatedByNewestModifiedTime()
        if deduplicated.count != entries.count {
            log(.warning, "Dedup removed \(entries.count - deduplicated.count) duplicate entries from data state")
        }
        log(.debug, "Updating data with \(deduplicated.count) entries")
        startUpdatingTotpCode(deduplicated.map(\.orderedEntry.entry))
        dataState = .loaded(deduplicated)
    }

    func fullRefresh() async throws {
        if let existing = fullRefreshTask {
            log(.debug, "Full BE refresh already in progress, joining existing task")
            try await existing.value
            return
        }

        let task = Task {
            try await performFullRefresh()
        }
        fullRefreshTask = task
        defer { fullRefreshTask = nil }
        try await task.value
    }

    func unsyncAllEntries() async throws {
        log(.debug, "Unsyncing all entries")
        do {
            try await repository.unsyncAllEntries()
            let entryStates = try await repository.getAllLocalEntries()
            let entries = try await generateUIEntries(from: entryStates.decodedEntries)
            updateData(entries)
        } catch {
            log(.error, "Failed to unsync all entries: \(error.localizedDescription)")
            throw error
        }
    }

    func deleteAllEntries() async throws {
        log(.debug, "Deleting all entries")
        do {
            let localEntries = try await repository.getAllLocalEncryptedEntries()

            let entryIdsToRemove = localEntries.map(\.id)

            try await repository.localRemoves(entryIdsToRemove)

            var remoteError: (any Error)?
            if let remoteEntries = try? await repository.fetchAllRemoteEntries() {
                do {
                    let ids = remoteEntries.compactMap(\.remoteId)
                    _ = try await repository.remoteDeletes(remoteEntryIds: ids)
                } catch {
                    remoteError = error
                }
            }

            try await loadEntries()

            if let remoteError {
                throw remoteError
            }
        } catch {
            log(.error, "Failed to delete all entries: \(error.localizedDescription)")
            throw error
        }
    }

    func backUpEntries() {
        guard settings.folderBackup else { return }

        do {
            let password: String = try keychainService.get(keyId: AppConstants.Settings.backupPassword,
                                                           isSynced: false)
            if let exportData = try exportEntries(password: password).data(using: .utf8) {
                try backUpManager.write(data: exportData)
            }
        } catch {
            log(.error, "Failed to backup entries: \(error)")
        }
    }
}

// MARK: - Rust exposure

public extension EntryDataService {
    func getTotpParams(entry: Entry) throws -> TotpParams {
        log(.debug, "Getting TOTP parameters for entry with ID: \(entry.id)")
        return try repository.getTotpParams(entry: entry)
    }

    func exportEntries(password: String?) throws -> String {
        log(.debug, password != nil ? "Exporting entries with password" : "Exporting entries")

        guard let data = dataState.data else {
            throw AuthError.generic(.exportEmptyData)
        }
        let entries = data.map(\.orderedEntry.entry)

        if let password {
            return try repository.export(entries: entries, with: password)
        } else {
            return try repository.export(entries: entries)
        }
    }

    func importEntries(from sources: [TwofaImportSource]) async throws -> Int {
        let results = try importService.importEntries(from: sources)
        var data: [EntryUiModel] = dataState.data ?? []
        let filteredResults = results.entries
            .filter { entry in !data.contains(where: { $0.orderedEntry.entry.isContentDuplicate(of: entry) }) }
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
        updateData(data)
        backUpEntries()
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
        log(.debug, "Starting updating TOTP codes for \(entries.count) entries")

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

    func performFullRefresh() async throws {
        log(.debug, "Full BE refresh")
        do {
            let entriesStates = try await repository.getAllLocalEntries()
            if Task.isCancelled { return }

            try await repository.fetchRemoteEncryptionKeyOrPushLocalKey()
            let remoteOrderedEntries = try await repository.fetchAllRemoteEntries()

            hasNonDecryptableEntries = entriesStates.containsNonDecryptedEntries
            if Task.isCancelled { return }
            _ = try await syncOperation(remoteOrderedEntries: remoteOrderedEntries,
                                        entriesStates: entriesStates)
            if Task.isCancelled { return }
            let newOrderedItems = try await reorderItems(remoteEntries: remoteOrderedEntries)
            let entries = try await generateUIEntries(from: newOrderedItems)
            updateData(entries)
            backUpEntries()
        } catch {
            log(.error, "Failed to fullRefresh: \(error.localizedDescription), error: \(error)")
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

    func performLoadingEntries() async throws {
        log(.debug, "Loading entries")
        do {
            if Task.isCancelled { return }
            let entryStates = try await repository.getAllLocalEntries()
            if Task.isCancelled { return }
            let entries = try await generateUIEntries(from: entryStates.decodedEntries)
            hasNonDecryptableEntries = entryStates.containsNonDecryptedEntries
            log(.debug, "Loaded \(entries.count) entries.")
            updateData(entries)
        } catch {
            log(.error, "Failed to load entries: \(error)")
            if let data = dataState.data, !data.isEmpty { return }
            dataState = .failed(error)
        }
    }

    func save(_ entry: Entry,
              remoteId: String? = nil) async throws {
        guard !savingEntryIds.contains(entry.id) else {
            log(.warning, "Entry \(entry.id) save already in progress, skipping duplicate call")
            return
        }
        savingEntryIds.insert(entry.id)
        defer { savingEntryIds.remove(entry.id) }

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
        let remoteResults = try await repository.completeSave(entries: [orderEntry])

        var entryUI = EntryUiModel(orderedEntry: orderEntry,
                                   code: code,
                                   issuerInfo: issuerInfo)
        if let remoteResult = remoteResults?.first {
            entryUI = entryUI.updateRemoteInfos(remoteResult.entryID)
        }

        data.append(entryUI)

        updateData(data)
        backUpEntries()
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

        for (index, uiEntry) in uiEntries.enumerated() {
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
        let codesByEntryId = Dictionary(newCodes.map { ($0.entry.id, $0) },
                                        uniquingKeysWith: { _, latest in latest })
        let updated = entries.map { entry -> EntryUiModel in
            guard let newCode = codesByEntryId[entry.id] else { return entry }
            return entry.updateCode(newCode)
        }
        dataState = .loaded(updated)
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
        if Task.isCancelled { return false }
        async let localEntriesFetch: () = repository.localUpsert(itemsToUpsertLocally)
        async let remoteSaveResults = repository.remoteSave(entries: itemsToPushToRemote)
        async let remoteUpdateResults = repository.remoteUpdates(entries: itemsToUpdateRemotely)
        async let localRemove: () = repository.localRemoves(itemIdsToDeleteLocally)
        async let fullyRemove: () = repository.completeRemoves(entries: itemsToFullyDelete)

        let (_, saveResults, updateResults, _, _) =
            try await (localEntriesFetch, remoteSaveResults, remoteUpdateResults, localRemove, fullyRemove)

        try await updateItemFromRemote(itemsToPushToRemote, saveResults, itemsToUpdateRemotely, updateResults)
        return !operations.isEmpty
    }

    @MainActor
    func reorderItems(remoteEntries: [OrderedEntry]) async throws -> [OrderedEntry] {
        let localEntries = try await repository.getAllLocalEntries()

        guard remoteEntries.map(\.id) != localEntries.decodedEntries.map(\.id) else {
            return localEntries.decodedEntries
        }

        return try await performReordering(remoteEntries: remoteEntries,
                                           localEntries: localEntries.decodedEntries)
    }

    @MainActor
    func performReordering(remoteEntries: [OrderedEntry],
                           localEntries: [OrderedEntry]) async throws -> [OrderedEntry] {
        let remoteIds = Set(remoteEntries.map(\.id))

        // Start with remote entries in their server-returned order
        // (this IS the "last reorder wins" order from any device)
        var result = remoteEntries

        // Append local-only entries (not yet pushed to remote) at the end,
        // preserving their relative local order
        let localOnlyEntries = localEntries
            .filter { !remoteIds.contains($0.id) }
            .sorted { $0.order < $1.order }
        result.append(contentsOf: localOnlyEntries)

        // Re-index sequentially: 0, 1, 2, ...
        let reindexed = result.enumerated().map { index, item in
            item.updateOrder(index)
        }

        // Determine which entries actually need a DB/remote order update
        var itemsToUpdate: [OrderedEntry] = []
        for entry in reindexed {
            let localOrder = localEntries.first { $0.id == entry.id }?.order
            let remoteOrder = remoteEntries.first { $0.id == entry.id }?.order

            if localOrder != entry.order || remoteOrder != entry.order {
                itemsToUpdate.append(entry)
            }
        }

        if !itemsToUpdate.isEmpty {
            try await repository.localReorder(itemsToUpdate)
        }

        return reindexed
    }

    func updateItemFromRemote(_ itemsToPushToRemote: [OrderedEntry],
                              _ saveResults: [RemoteEncryptedEntry],
                              _ itemsToUpdateRemotely: [OrderedEntry],
                              _ updateResults: [RemoteEncryptedEntry]) async throws {
        // Update local entities with remote response data (remoteId, revision, modifiedTime, etc.)
        var resultByEntryId = [String: RemoteEncryptedEntry]()
        for (index, entry) in itemsToPushToRemote.enumerated() where index < saveResults.count {
            resultByEntryId[entry.id] = saveResults[index]
        }
        for entry in itemsToUpdateRemotely {
            guard let remoteId = entry.remoteId,
                  let result = updateResults.first(where: { $0.entryID == remoteId }) else { continue }
            resultByEntryId[entry.id] = result
        }
        try await repository.updateLocalEntitiesWithRemoteResponse(resultByEntryId)
    }
}

extension [EntryState] {
    var decodedEntries: [OrderedEntry] {
        compactMap(\.entry)
    }

    var containsNonDecryptedEntries: Bool {
        contains(where: \.isNonDecryptable)
    }

    func getFirstOrderedEntry(for entryId: String) -> OrderedEntry? {
        decodedEntries.getFirstOrderedEntry(for: entryId)
    }
}

public extension DataState<[EntryUiModel]> {
    var orderEntries: [OrderedEntry] {
        data?.map(\.orderedEntry) ?? []
    }
}

extension [OrderedEntry] {
    func getFirstOrderedEntry(for entryId: String) -> OrderedEntry? {
        self.first { $0.entry.id == entryId }
    }
}

// swiftlint:enable file_length
