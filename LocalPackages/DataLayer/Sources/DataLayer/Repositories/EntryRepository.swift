//
// EntryRepository.swift
// Proton Authenticator - Created on 11/02/2025.
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
import Foundation
import Models
import SimplyPersist
import SwiftData

// swiftlint:disable line_length file_length
public protocol EntryRepositoryProtocol: Sendable {
    // MARK: - Uri parsing and params from rust lib

    func entry(for uri: String) async throws -> Entry
    func export(entries: [Entry]) throws -> String
    func export(entries: [Entry], with password: String) throws -> String
    func generateCodes(entries: [Entry], time: TimeInterval) throws -> [Code]
    func createSteamEntry(params: SteamParams) throws -> Entry
    func createTotpEntry(params: TotpParams) throws -> Entry
    // periphery:ignore
    func serialize(entries: [Entry]) throws -> [Data]
    // periphery:ignore
    func deserialize(serializedData: [Data]) throws -> [Entry]
    func getTotpParams(entry: Entry) throws -> TotpParams

    // MARK: - local CRUD

    func getAllLocalEntries() async throws -> (entries: [EntryState], duplicateCount: Int)
    func getDuplicateEntryGroups() async throws -> [DuplicateEntryGroup]
    func deleteLocalDuplicate(entryId: String, modifiedTime: TimeInterval, creationDate: TimeInterval) async throws
    func localUpsert(_ entries: [OrderedEntry]) async throws
    // periphery:ignore
    func localRemoves(_ entriesId: [String]) async throws

    // periphery:ignore
    func localRemoveAll() async throws
    func localUpdate(_ entry: OrderedEntry) async throws -> OrderedEntry?
    func localReorder(_ entries: [OrderedEntry]) async throws

    func unsyncAllEntries() async throws

    @_spi(QA)
    func reset(keyIds: [String]) async throws
    @_spi(QA)
    func resetRemoteKeys() async

    @_spi(QA)
    func getAllLocalEncryptedEntries() async throws -> [EncryptedEntryEntity]

    /// Creates a new test TOTP entry, saves it (+ remote if connected), then inserts a duplicate
    /// local row with `modifiedTime - 100` to simulate a real duplicate scenario.
    /// - Returns: `true` if the entry was also synced to remote, `false` if local only.
    @_spi(QA)
    func generateDuplicateEntry() async throws -> Bool

    // MARK: - Remote Proton BE CRUD

    func remoteSave(entries: [OrderedEntry]) async throws -> [RemoteEncryptedEntry]
    func remoteUpdate(entry: OrderedEntry) async throws -> RemoteEncryptedEntry
    func remoteUpdates(entries: [OrderedEntry]) async throws -> [RemoteEncryptedEntry]
    func updateLocalEntitiesWithRemoteResponse(_ resultByEntryId: [String: RemoteEncryptedEntry]) async throws

    func remoteDeletes(remoteEntryIds: [String]) async throws
    func singleItemRemoteReordering(entryId: String, entries: [OrderedEntry]) async throws
    func batchRemoteReordering(entries: [OrderedEntry]) async throws
    func fetchAllRemoteEntries() async throws -> [OrderedEntry]
    func fetchRemoteEncryptionKeyOrPushLocalKey() async throws

    // MARK: - Full CRUD

    func completeSave(entries: [OrderedEntry]) async throws -> [RemoteEncryptedEntry]?
    func completeRemoves(entries: [OrderedEntry]) async throws
    func completeUpdate(entry: OrderedEntry, oldEntry: OrderedEntry) async throws
    func completeReorder(entries: [OrderedEntry]) async throws
}

public extension EntryRepositoryProtocol {
    func localUpsert(_ entry: OrderedEntry) async throws {
        try await localUpsert([entry])
    }
}

public extension EntryRepositoryProtocol {
    func generateCodes(entries: [Entry]) throws -> [Code] {
        try generateCodes(entries: entries, time: Date().timeIntervalSince1970)
    }
}

public actor EntryRepository: EntryRepositoryProtocol {
    private let rustClient: AuthenticatorMobileClientProtocol
    private let localDataManager: any LocalDataManagerProtocol
    private let encryptionService: any EncryptionServicing
    private let apiClient: any APIClientProtocol
    private let userSessionManager: any UserSessionTooling
    private let store: UserDefaults
    private let logger: any LoggerProtocol

    private let entryContentFormatVersion = AppConstants.ContentFormatVersion.entry
    private let currentRemoteEncryptionKeyId = AppConstants.Settings.remoteEncryptionKeyId

    private var isAuthenticated: Bool {
        userSessionManager.isAuthenticatedWithUserData.value
    }

    private var remoteEncryptionKeyId: String? {
        store.string(forKey: currentRemoteEncryptionKeyId)
    }

    public init(localDataManager: any LocalDataManagerProtocol,
                encryptionService: any EncryptionServicing,
                apiClient: any APIClientProtocol,
                userSessionManager: any UserSessionTooling,
                store: UserDefaults,
                logger: any LoggerProtocol,
                rustClient: any AuthenticatorMobileClientProtocol = AuthenticatorMobileClient()) {
        self.localDataManager = localDataManager
        self.encryptionService = encryptionService
        self.apiClient = apiClient
        self.userSessionManager = userSessionManager
        self.rustClient = rustClient
        self.store = store
        self.logger = logger
    }
}

// MARK: - Uri parsing and params from rust lib

public extension EntryRepository {
    func entry(for uri: String) async throws -> Entry {
        try rustClient.entryFromUri(uri: uri).toEntry
    }

    nonisolated func export(entries: [Entry]) throws -> String {
        try rustClient.exportEntries(entries: entries.toRustEntries)
    }

    nonisolated func export(entries: [Entry], with password: String) throws -> String {
        try rustClient.exportEntriesWithPassword(entries: entries.toRustEntries, password: password)
    }

    nonisolated func deserialize(serializedData: [Data]) throws -> [Entry] {
        try rustClient.deserializeEntries(entries: serializedData).toEntries
    }

    nonisolated func generateCodes(entries: [Entry], time: TimeInterval) throws -> [Code] {
        try rustClient.generateCodes(entries: entries.toRustEntries, time: UInt64(time)).toCodes
    }

    nonisolated func createSteamEntry(params: SteamParams) throws -> Entry {
        try rustClient.newSteamEntryFromParams(params: params.toRustParams).toEntry
    }

    nonisolated func createTotpEntry(params: TotpParams) throws -> Entry {
        try rustClient.newTotpEntryFromParams(params: params.toRustParams).toEntry
    }

    nonisolated func serialize(entries: [Entry]) throws -> [Data] {
        try rustClient.serializeEntries(entries: entries.toRustEntries)
    }

    nonisolated func getTotpParams(entry: Entry) throws -> TotpParams {
        let params = try rustClient.getTotpParams(entry: entry.toRustEntry)

        return TotpParams(name: entry.name,
                          secret: params.secret,
                          issuer: params.issuer ?? "",
                          period: Int(params.period),
                          digits: Int(params.digits),
                          algorithm: params.algorithm.toTotpAlgorithm,
                          note: entry.note)
    }
}

// MARK: - local & remote CRUD

public extension EntryRepository {
    func completeSave(entries: [OrderedEntry]) async throws -> [RemoteEncryptedEntry]? {
        try await localUpsert(entries)
        if isAuthenticated {
            do {
                let remoteResults = try await remoteSave(entries: entries)
                // Build mapping using array position: entries and results are in the same order
                var resultByEntryId = [String: RemoteEncryptedEntry]()
                for (index, entry) in entries.enumerated() where index < remoteResults.count {
                    resultByEntryId[entry.id] = remoteResults[index]
                }
                try await updateLocalEntitiesWithRemoteResponse(resultByEntryId)
                return remoteResults
            } catch {
                log(.error, "Failed to remote save: \(error.localizedDescription)")
            }
        }
        return nil
    }

    func completeRemoves(entries: [OrderedEntry]) async throws {
        if isAuthenticated {
            do {
                try await remoteDeletes(remoteEntryIds: entries.compactMap(\.remoteId))
            } catch {
                log(.error, "Failed to remote deletes \(entries.map(\.id)) \(error.localizedDescription)")
                throw error
//
//                print("woot error while deleting item remotly: \(error)")
//                if error.httpCode != 422 {
//                    let entryIDs = entries.map((\.id))
//                    let predicate = #Predicate<EncryptedEntryEntity> { entryIDs.contains($0.id) }
//                    let entities = try await localDataManager.persistentStorage.fetch(predicate: predicate)
//                    guard !entities.isEmpty else {
//                        log(.warning, "Cannot find local entries with IDs: \(entryIDs)")
//                        return
//                    }
//                    try? await localDataManager.persistentStorage.performTransaction {
//                        entities.switchToDelete()
//                    }
//                    return
//                }
            }
        }

        try await localRemoves(entries.map(\.id))
    }

    func completeUpdate(entry: OrderedEntry, oldEntry: OrderedEntry) async throws {
        let orderedEntity = try await localUpdate(entry)
        if isAuthenticated, let orderedEntity {
            do {
                let result = try await remoteUpdate(entry: orderedEntity)
                try await updateLocalEntitiesWithRemoteResponse([entry.id: result])
            } catch {
                log(.error, "Failed to remote update \(entry.id) \(error.localizedDescription)")
                log(.warning, "Revert local update \(entry.id)")
                _ = try await localUpdate(oldEntry)
                throw error
            }
        }
    }

    func completeReorder(entries: [OrderedEntry]) async throws {
        try await localReorder(entries)
        if isAuthenticated {
            do {
                try await batchRemoteReordering(entries: entries)
            } catch {
                log(.error, "Failed to remote reorder: \(error.localizedDescription)")
                throw error
            }
        }
    }
}

// MARK: - CLoud / local CRUD

public extension EntryRepository {
    func getAllLocalEntries() async throws -> (entries: [EntryState], duplicateCount: Int) {
        log(.debug, "Fetching all local entries")
        var entriesDuplicated = [EncryptedEntryEntity]()

        do {
            let encryptedEntries: [EncryptedEntryEntity] = try await localDataManager.persistentStorage
                .fetch(predicate: nil,
                       sortingDescriptor: [
                           SortDescriptor(\.modifiedTime, order: .reverse)
                       ])

            // Step 2: Deduplicate based on most recent modifiedTime
            var latestEntriesById = [String: EncryptedEntryEntity]()

            for entry in encryptedEntries {
                if latestEntriesById[entry.id] == nil {
                    latestEntriesById[entry.id] = entry // First (i.e., latest) occurrence
                } else {
                    entriesDuplicated.append(entry) // Older duplicate
                }
            }

            let entriesToDecrypt = Array(latestEntriesById.values).sorted {
                if $0.order != $1.order {
                    $0.order < $1.order
                } else {
                    $0.id < $1.id
                }
            }

            // Step 3: Decrypt and sort by 'order'
            let decryptedEntries = try encryptionService.decrypt(entries: entriesToDecrypt)

            let nonDecryptableCount = decryptedEntries.count(where: { $0.isNonDecryptable })
            let decryptableCount = decryptedEntries.count(where: { !$0.isNonDecryptable })

            log(.info,
                "Successfully fetched \(decryptableCount) decryptable, \(nonDecryptableCount) non decryptable")
            if !entriesDuplicated.isEmpty {
                log(.warning,
                    "Found \(entriesDuplicated.count) duplicate entries with ids: \(entriesDuplicated.map(\.id))")
            }

            return (decryptedEntries, entriesDuplicated.count)
        } catch {
            log(.error, "Failed to fetch local entries: \(error.localizedDescription)")
            throw error
        }
    }

    func getDuplicateEntryGroups() async throws -> [DuplicateEntryGroup] {
        let allEntities: [EncryptedEntryEntity] = try await localDataManager.persistentStorage
            .fetch(predicate: nil,
                   sortingDescriptor: [SortDescriptor(\.modifiedTime, order: .reverse)])

        var groupedById = [String: [EncryptedEntryEntity]]()
        for entity in allEntities {
            groupedById[entity.id, default: []].append(entity)
        }

        var groups = [DuplicateEntryGroup]()

        for (entryId, entities) in groupedById where entities.count > 1 {
            let decryptedStates = try encryptionService.decrypt(entries: entities)

            var groupDisplayName = entryId
            var groupIssuer = ""
            for state in decryptedStates {
                if case let .decrypted(_, orderedEntry) = state {
                    groupDisplayName = orderedEntry.entry.name
                    groupIssuer = orderedEntry.entry.issuer
                    break
                }
            }

            let infos: [DuplicateEntryInfo] = decryptedStates.enumerated().map { index, state in
                var name = groupDisplayName
                var issuer = groupIssuer
                if case let .decrypted(_, orderedEntry) = state {
                    name = orderedEntry.entry.name
                    issuer = orderedEntry.entry.issuer
                }
                return DuplicateEntryInfo(entryId: state.encryptedEntry.id,
                                          modifiedTime: state.encryptedEntry.modifiedTime,
                                          displayName: name,
                                          issuer: issuer,
                                          isCurrentlyActive: index == 0)
            }

            groups.append(DuplicateEntryGroup(entryId: entryId,
                                              displayName: groupDisplayName,
                                              issuer: groupIssuer,
                                              entries: infos))
        }

        return groups.sorted { $0.displayName.lowercased() < $1.displayName.lowercased() }
    }

    func deleteLocalDuplicate(entryId: String,
                              modifiedTime: TimeInterval,
                              creationDate: TimeInterval) async throws {
        log(.debug,
            "Deleting duplicate for entryId: \(entryId), modifiedTime: \(modifiedTime), creationDate: \(creationDate)")
        let predicate = #Predicate<EncryptedEntryEntity> {
            $0.id == entryId && $0.modifiedTime == modifiedTime && $0.creationDate == creationDate
        }
        try await localDataManager.persistentStorage.delete(EncryptedEntryEntity.self, predicate: predicate)
        log(.info, "Deleted duplicate for entryId: \(entryId)")
    }

    func localUpsert(_ entries: [OrderedEntry]) async throws {
        log(.debug, "Upserting \(entries.count) entries")
        do {
            // Fetch entities that already exist for the ids (as we cannot leverage swiftData `.unique` with
            // iCloud)
            // to remove duplicates.
            let idsToFetch: [String] = entries.map(\.id)
            let predicate = #Predicate<EncryptedEntryEntity> { entity in
                idsToFetch.contains(entity.id)
            }

            let encryptedEntries: [EncryptedEntryEntity] = try await localDataManager.persistentStorage
                .fetch(predicate: predicate)
            let currentLocalIds = encryptedEntries.map(\.id)
            log(.debug, "Found \(encryptedEntries.count) existing entries")

            if !currentLocalIds.isEmpty {
                let entitiesToUpdate = entries.filter { currentLocalIds.contains($0.id) }
                try await localUpdates(encryptedEntries: encryptedEntries, entriesToUpdate: entitiesToUpdate)
            }

            let newEntries = entries.filter { !currentLocalIds.contains($0.id) }

            guard !newEntries.isEmpty else {
                return
            }
            log(.debug, "Adding \(newEntries.count) new entries")

            let newEncryptedEntries = try newEntries.map { try encrypt($0,
                                                                       encryptionKeyId: encryptionService
                                                                           .localEncryptionKeyId)
            }

            try await localDataManager.persistentStorage.batchSave(content: newEncryptedEntries)
            log(.info, "Successfully saved \(newEncryptedEntries.count) new entries locally")
        } catch {
            log(.error, "Failed to save entries: \(error.localizedDescription)")
            throw error
        }
    }

    private func localUpdates(encryptedEntries: [EncryptedEntryEntity],
                              entriesToUpdate: [OrderedEntry]) async throws {
        do {
            try await localDataManager.persistentStorage.performTransaction { [weak self] in
                guard let self else {
                    return
                }
                for orderedEntry in entriesToUpdate {
                    guard let keyId = orderedEntry.keyId,
                          let encryptedEntry = encryptedEntries.first(where: { $0.id == orderedEntry.id })

                    else { continue }

                    let encryptedData = try encryptionService.encrypt(entry: orderedEntry.entry,
                                                                      keyId: keyId)
                    encryptedEntry.updateEncryptedData(encryptedData,
                                                       with: keyId,
                                                       remoteModifiedTime: orderedEntry.modifiedTime)
                    encryptedEntry.update(with: orderedEntry)
                }
            }
            log(.info, "Successfully updated \(encryptedEntries.count) entries locally")
        } catch {
            log(.error, "Failed to update entries: \(error.localizedDescription)")
            throw error
        }
    }

    func localRemoves(_ entriesId: [String]) async throws {
        guard !entriesId.isEmpty else {
            return
        }
        log(.debug, "Deleting entries with ids \(entriesId) from local storage")
        let predicate = #Predicate<EncryptedEntryEntity> { entriesId.contains($0.id) }
        try await localDataManager.persistentStorage.delete(EncryptedEntryEntity.self, predicate: predicate)
        log(.info, "Successfully deleted entries \(entriesId) from local storage")
    }

    func localRemoveAll() async throws {
        log(.info, "Removing all entries from local storage")
        try await localDataManager.persistentStorage.deleteAll(dataTypes: [EncryptedEntryEntity.self])
        log(.info, "Successfully removed all entries from local storage")
    }

    /// Updates all local entities (including duplicates) with remote response data.
    /// - Parameter resultByEntryId: Maps entry id → `RemoteEncryptedEntry` from the BE response.
    func updateLocalEntitiesWithRemoteResponse(_ resultByEntryId: [String: RemoteEncryptedEntry]) async throws {
        guard !resultByEntryId.isEmpty else { return }
        let idsToFetch = Array(resultByEntryId.keys)
        let predicate = #Predicate<EncryptedEntryEntity> { idsToFetch.contains($0.id) }
        let allEntities: [EncryptedEntryEntity] = try await localDataManager.persistentStorage
            .fetch(predicate: predicate)

        guard !allEntities.isEmpty else {
            log(.debug, "No local entities found for remote response update")
            return
        }

        try await localDataManager.persistentStorage.performTransaction {
            for entity in allEntities {
                guard let result = resultByEntryId[entity.id] else { continue }
                entity.update(with: result)
            }
        }
        log(.debug, "Updated \(allEntities.count) local entities with remote response")
    }

    func localUpdate(_ entry: OrderedEntry) async throws -> OrderedEntry? {
        log(.debug, "Updating entry with ID: \(entry.id)")
        do {
            let entryId = entry.id
            guard let entity = try await localDataManager.persistentStorage
                .fetchOne(predicate: #Predicate<EncryptedEntryEntity> { $0.id == entryId }) else {
                log(.warning, "Cannot find local entry with ID: \(entry.id) for update")
                return nil
            }
            log(.debug, "Found local entry, encrypting updated data")

            let encryptedData = try encryptionService.encrypt(entry: entry.entry,
                                                              keyId: entity.keyId)
            try await localDataManager.persistentStorage.performTransaction {
                entity.updateEncryptedData(encryptedData,
                                           with: entity.keyId,
                                           remoteModifiedTime: entry.modifiedTime)
                entity.updateSyncState(newState: entry.syncState)
            }

            log(.info, "Successfully updated entry \(entry.id) in local storage")
            return OrderedEntry(entry: entry.entry,
                                keyId: localKeyId,
                                remoteId: entity.remoteId,
                                order: entity.order,
                                syncState: entry.syncState,
                                modifiedTime: entity.modifiedTime,
                                revision: entity.revision,
                                contentFormatVersion: entryContentFormatVersion)
        } catch {
            log(.error, "Failed to update entry \(entry.id): \(error.localizedDescription)")
            throw error
        }
    }

    func localReorder(_ entries: [OrderedEntry]) async throws {
        log(.debug, "Updating order for \(entries.count) entries")
        do {
            let idsToFetch: [String] = entries.map(\.id)
            let predicate = #Predicate<EncryptedEntryEntity> { entity in
                idsToFetch.contains(entity.id)
            }
            let encryptedEntries: [EncryptedEntryEntity] = try await localDataManager.persistentStorage
                .fetch(predicate: predicate)

            log(.debug, "Found \(encryptedEntries.count) local entries for order update")

            if encryptedEntries.count != entries.count {
                log(.warning,
                    "Duplicate entries detected during reorder: expected \(entries.count), found \(encryptedEntries.count)")
            }

            try await localDataManager.persistentStorage.performTransaction {
                for entity in encryptedEntries {
                    guard let orderedEntry = entries.first(where: { $0.id == entity.id }) else { continue }
                    entity.updateOrder(newOrder: orderedEntry.order, remoteModifiedTime: orderedEntry.modifiedTime)
                }
            }
            log(.info, "Successfully saved updated order to local storage")
        } catch {
            log(.error, "Failed to update entry order: \(error.localizedDescription)")
            throw error
        }
    }

    func unsyncAllEntries() async throws {
        let encryptedEntries: [EncryptedEntryEntity] = try await localDataManager.persistentStorage.fetch()
        try await localDataManager.persistentStorage.performTransaction {
            for entry in encryptedEntries {
                entry.updateSyncState(newState: .unsynced)
            }
        }
    }

    func reset(keyIds: [String]) async throws {
        for keyId in keyIds {
            try encryptionService.reset(keyId: keyId)
        }
    }

    func resetRemoteKeys() async {
        if let encryptedKeysData = try? await apiClient.getKeys() {
            for keyData in encryptedKeysData {
                encryptionService.reset(remoteKeyId: keyData.keyID)
            }
        }
        if let remoteKeychainEncryptionKeyId = kSharedUserDefaults
            .string(forKey: AppConstants.Settings.remoteEncryptionKeyId) {
            encryptionService.reset(remoteKeyId: remoteKeychainEncryptionKeyId)
        }
    }

    func getAllLocalEncryptedEntries() async throws -> [EncryptedEntryEntity] {
        try await localDataManager.persistentStorage.fetch(predicate: nil)
    }

    func generateDuplicateEntry() async throws -> Bool {
        let newId = UUID().uuidString
        let testEntry = Entry(id: newId,
                              name: "QA Duplicate Test",
                              uri: "otpauth://totp/QA%3ATest?secret=JBSWY3DPEHPK3PXP&issuer=QA&period=30",
                              period: 30,
                              issuer: "QA",
                              secret: "JBSWY3DPEHPK3PXP",
                              type: .totp,
                              note: nil)
        let now = Date.now.timeIntervalSince1970
        let orderedEntry = OrderedEntry(entry: testEntry,
                                        keyId: encryptionService.localEncryptionKeyId,
                                        remoteId: nil,
                                        order: 0,
                                        modifiedTime: now,
                                        revision: 0,
                                        contentFormatVersion: entryContentFormatVersion)

        let remoteResults = try await completeSave(entries: [orderedEntry])

        // Fetch the entity (possibly updated with remote data) and insert a duplicate with an older modifiedTime
        let predicate = #Predicate<EncryptedEntryEntity> { $0.id == newId }
        let entities: [EncryptedEntryEntity] = try await localDataManager.persistentStorage
            .fetch(predicate: predicate)
        guard let entity = entities.max(by: { $0.modifiedTime < $1.modifiedTime }) else {
            return remoteResults != nil
        }

        let duplicate = EncryptedEntryEntity(id: entity.id,
                                             encryptedData: entity.encryptedData,
                                             remoteId: entity.remoteId,
                                             keyId: entity.keyId,
                                             order: entity.order,
                                             syncState: entity.syncState,
                                             creationDate: entity.creationDate,
                                             modifiedTime: entity.modifiedTime - 100,
                                             flags: entity.flags,
                                             contentFormatVersion: entity.contentFormatVersion,
                                             revision: entity.revision)
        try await localDataManager.persistentStorage.batchSave(content: [duplicate])
        return remoteResults != nil
    }
}

// MARK: - Remote proton BE CRUD for entries

public extension EntryRepository {
    func remoteSave(entries: [OrderedEntry]) async throws -> [RemoteEncryptedEntry] {
        guard !entries.isEmpty else { return [] }
        log(.debug, "Saving \(entries.count) entries to remote")

        guard let remoteEncryptionKeyId else {
            log(.error, "No remote key ID registered for remote save")
            throw AuthError.crypto(.missingRemoteEncryptionKey)
        }

        do {
            let encryptedRequests = try entries.map { entry in
                let encryptedData = try encryptionService.encrypt(entry: entry.entry,
                                                                  keyId: remoteEncryptionKeyId)
                return StoreEntryRequest(authenticatorKeyID: remoteEncryptionKeyId,
                                         content: encryptedData.encodeBase64(),
                                         contentFormatVersion: entryContentFormatVersion)
            }

            let batches = encryptedRequests.chunked(into: AppConstants.NetworkSettings.batchSize)

            let combinedResults: [RemoteEncryptedEntry] =
                try await withThrowingTaskGroup(of: (Int, [RemoteEncryptedEntry]).self) { [weak self] group in
                    guard let self else { return [] }

                    for (index, batch) in batches.enumerated() {
                        group.addTask {
                            let result = try await self.apiClient
                                .storeEntries(request: StoreEntriesRequest(entries: batch))
                            return (index, result)
                        }
                    }

                    var resultsByIndex = Array(repeating: [RemoteEncryptedEntry](), count: batches.count)

                    for try await (index, batchResult) in group {
                        resultsByIndex[index] = batchResult
                    }

                    return resultsByIndex.flatMap(\.self)
                }

            log(.info, "Successfully stored \(combinedResults.count) entries on remote")
            return combinedResults
        } catch {
            log(.error, "Failed to store entries on remote: \(error.localizedDescription)")
            throw error
        }
    }

    func remoteUpdate(entry: OrderedEntry) async throws -> RemoteEncryptedEntry {
        log(.debug, "Updating entry with id \(entry.id) on remote")

        guard let remoteEncryptionKeyId else {
            log(.error, "No remote key ID registered for remote update")
            throw AuthError.crypto(.missingRemoteEncryptionKey)
        }

        guard let remoteId = entry.remoteId else {
            log(.error, "No remote id linked to entry for remote update")
            throw AuthError.generic(.missingRemoteId)
        }

        do {
            let encryptedData = try encryptionService.encrypt(entry: entry.entry,
                                                              keyId: remoteEncryptionKeyId)
            let request = UpdateEntryRequest(authenticatorKeyID: remoteEncryptionKeyId,
                                             content: encryptedData.encodeBase64(),
                                             contentFormatVersion: entryContentFormatVersion,
                                             lastRevision: entry.revision)

            let result = try await apiClient.update(entryId: remoteId, request: request)
            log(.info, "Successfully updated entry with id \(remoteId) on remote")
            return result
        } catch {
            log(.error, "Failed to update entry with id \(remoteId) on remote: \(error.localizedDescription)")
            throw error
        }
    }

    func remoteUpdates(entries: [OrderedEntry]) async throws -> [RemoteEncryptedEntry] {
        guard !entries.isEmpty else { return [] }

        guard let remoteEncryptionKeyId else {
            log(.error, "No remote key ID registered for remote update")
            throw AuthError.crypto(.missingRemoteEncryptionKey)
        }

        let encryptedRequests = try entries.compactMap { entry -> BatchUpdateEntryRequest? in
            guard let remoteId = entry.remoteId else { return nil }
            let encryptedData = try encryptionService.encrypt(entry: entry.entry,
                                                              keyId: remoteEncryptionKeyId)
            return BatchUpdateEntryRequest(entryID: remoteId,
                                           authenticatorKeyID: remoteEncryptionKeyId,
                                           content: encryptedData.encodeBase64(),
                                           contentFormatVersion: entryContentFormatVersion,
                                           lastRevision: entry.revision)
        }

        let batches = encryptedRequests.chunked(into: AppConstants.NetworkSettings.batchSize)
        var combinedResults: [RemoteEncryptedEntry] = []

        // Process batches in parallel
        try await withThrowingTaskGroup(of: [RemoteEncryptedEntry].self) { [weak self] group in
            guard let self else {
                return
            }
            for batch in batches {
                group.addTask {
                    try await self.apiClient.updates(request: UpdateEntriesRequest(entries: batch))
                }
            }

            for try await batchResult in group {
                combinedResults.append(contentsOf: batchResult)
            }
        }

        return combinedResults
    }

    func remoteDeletes(remoteEntryIds: [String]) async throws {
        guard !remoteEntryIds.isEmpty else { return }

        let batches = remoteEntryIds.chunked(into: AppConstants.NetworkSettings.batchSize)

        // Process batches in parallel
        try await withThrowingTaskGroup(of: Void.self) { [weak self] group in
            guard let self else {
                return
            }
            for batch in batches {
                group.addTask {
                    try await self.apiClient.delete(entryIds: batch)
                }
            }

            try await group.waitForAll()
        }
    }

    func singleItemRemoteReordering(entryId: String, entries: [OrderedEntry]) async throws {
        log(.debug, "Updating order for entry \(entryId) on remote")

        var previousRemoteID: String?
        if let index = entries.firstIndex(where: { $0.id == entryId }), index > 0 {
            previousRemoteID = entries[index - 1].remoteId
            log(.debug, "Entry will be positioned after entry with remote ID: \(previousRemoteID ?? "nil")")
        }

        do {
            let request = NewOrderRequest(afterID: previousRemoteID)
            _ = try await apiClient.changeOrder(entryId: entryId, request: request)
            log(.info, "Successfully updated order for entry \(entryId) on remote")
        } catch {
            log(.error, "Failed to update order for entry \(entryId) on remote: \(error.localizedDescription)")
            throw error
        }
    }

    func batchRemoteReordering(entries: [OrderedEntry]) async throws {
        log(.debug, "Updating order for multiple entries on remote")

        do {
            let batches: [[String]] = entries
                .compactMap(\.remoteId)
                .chunked(into: 500)
            for (index, batch) in batches.enumerated() {
                log(.debug, "Sending batch \(index + 1)/\(batches.count)")
                let request = BatchOrderRequest(startingPosition: index * 500, entries: batch)
                _ = try await apiClient.batchOrdering(request: request)
            }
        } catch {
            log(.error,
                "Failed to update order of  \(entries.count) entries on remote: \(error.localizedDescription)")
            throw error
        }
        log(.debug, "Successfully updated order for multiple entries on remote")
    }

    func fetchAllRemoteEntries() async throws -> [OrderedEntry] {
        log(.debug, "Fetching entries from remote")

        do {
            var localIdSet = Set<String>()

            if let allLocalEntities: [EncryptedEntryEntity] = try? await localDataManager.persistentStorage
                .fetch(predicate: nil), !allLocalEntities.isEmpty {
                localIdSet = Set(allLocalEntities.map(\.id))
            }

            var sinceLastToken: String?

            var entries: [OrderedEntry] = []
            var index = 0
            while true {
                let encryptedEntries = try await apiClient.getEntries(lastId: sinceLastToken)
                log(.debug, "Retrieved \(encryptedEntries.entries.count) encrypted entries from remote")
                if encryptedEntries.entries.isEmpty {
                    break
                }

                for encryptedEntry in encryptedEntries.entries {
                    if !encryptionService.contains(keyId: encryptedEntry.authenticatorKeyID) {
                        log(.debug,
                            "Missing key \(encryptedEntry.authenticatorKeyID) for entry \(encryptedEntry.entryID), fetching keys")
                        try await fetchRemoteEncryptionKeyOrPushLocalKey()
                    }
                    guard let decryptedEntry = try encryptionService
                        .decryptRemoteData(encryptedData: encryptedEntry) else {
                        continue
                    }

                    let syncState: EntrySyncState = localIdSet.contains(decryptedEntry.id) ? .synced : .unsynced

                    let orderedEntry = OrderedEntry(entry: decryptedEntry,
                                                    keyId: nil,
                                                    remoteId: encryptedEntry.entryID,
                                                    order: index,
                                                    syncState: syncState,
                                                    creationDate: Double(encryptedEntry.createTime),
                                                    modifiedTime: Double(encryptedEntry.modifyTime),
                                                    flags: encryptedEntry.flags,
                                                    revision: encryptedEntry.revision,
                                                    contentFormatVersion: encryptedEntry.contentFormatVersion)
                    entries.append(orderedEntry)
                    index += 1
                }
                sinceLastToken = encryptedEntries.lastID
                log(.info, "Successfully fetched and decrypted \(entries.count) entries from remote")
            }
            return entries
        } catch {
            log(.error, "Failed to fetch entries from remote: \(error.localizedDescription)")
            throw error
        }
    }
}

// MARK: - Remote util functions for encryption key

extension EntryRepository {
    /// This function fetches check if a remtoe encryption key exists for the user.
    /// If a key exists it saves it's id in the store and return.
    /// Otherwise it tries and push the local encryption key to the BE
    public func fetchRemoteEncryptionKeyOrPushLocalKey() async throws {
        log(.info, "Initiating fetch or push of encryption keys")
        let currentEncryptionKey: RemoteEncryptedKey?

        if let remoteEncryptionKey = try await fetchAndSaveRemoteKeys() {
            log(.info, "Remote key already exists, with id: \(remoteEncryptionKey.keyID)")
            currentEncryptionKey = remoteEncryptionKey
        } else {
            log(.debug, "No remote key found, sending new encryption key to backend")
            currentEncryptionKey = try await sendNewRemoteEncryptionKey()
        }

        store.set(currentEncryptionKey?.keyID, forKey: currentRemoteEncryptionKeyId)
        log(.info, "Stored remote key ID: \(currentEncryptionKey?.keyID ?? "unknown")")
    }

    private func sendNewRemoteEncryptionKey() async throws -> RemoteEncryptedKey? {
        log(.debug, "Sending a new encryption key to remote")

        guard userSessionManager.isAuthenticatedWithUserData.value else {
            log(.warning, "Cannot send new encryption key: user not authenticated")
            return nil
        }

        do {
            let key = encryptionService.generateKey()
            log(.debug, "Encrypting new encryption key for remote storage")
            let encryptedKey = try userSessionManager.userKeyEncrypt(object: key)
            let result = try await apiClient.storeKey(encryptedKey: encryptedKey)
            try encryptionService.saveUserRemoteKey(keyId: result.keyID, remoteKey: key)
            log(.info, "Successfully stored local encryption key on remote with ID: \(result.keyID)")
            return result
        } catch {
            log(.error, "Failed to send local encryption key to remote: \(error.localizedDescription)")
            throw error
        }
    }

    /// This function fetches current user remotly stored keys
    /// It then decrypts and saved all missing keys in the `encryptionService` keychain
    /// It then returns the current remote encryption key linked to the active user key (Should always be a maximum
    /// of one key)
    private func fetchAndSaveRemoteKeys() async throws -> RemoteEncryptedKey? {
        log(.debug, "Fetching remote encryption keys")
        do {
            let encryptedKeysData = try await apiClient.getKeys()
            log(.debug, "Retrieved \(encryptedKeysData.count) remote encryption keys")

            var newKeysAdded = 0
            for encryptedKeyData in
                encryptedKeysData /* where !encryptionService.contains(keyId: encryptedKeyData.keyID) */ {
                log(.debug, "Processing new key with ID: \(encryptedKeyData.keyID)")

                let keyDecrypted = try userSessionManager.userKeyDecrypt(remoteEncryptedKey: encryptedKeyData)
                try encryptionService.saveUserRemoteKey(keyId: encryptedKeyData.keyID, remoteKey: keyDecrypted)
                newKeysAdded += 1
            }
            log(.info, "Successfully processed remote keys, added \(newKeysAdded) new keys")

            return try userSessionManager
                .getRemoteEncryptionKeyLinkedToActiveUserKey(encryptedKeysData)
        } catch {
            log(.error, "Failed to fetch and save remote keys: \(error.localizedDescription)")
            throw error
        }
    }
}

// MARK: - Utils

private extension EntryRepository {
    func encrypt(_ entry: OrderedEntry,
                 encryptionKeyId: String) throws -> EncryptedEntryEntity {
        let remoteId = entry.remoteId ?? ""

        let encryptedData = try encryptionService.encrypt(entry: entry.entry,
                                                          keyId: encryptionKeyId)
        return EncryptedEntryEntity(id: entry.id,
                                    encryptedData: encryptedData,
                                    remoteId: remoteId,
                                    keyId: encryptionKeyId,
                                    order: entry.order,
                                    syncState: entry.syncState,
                                    creationDate: entry.creationDate,
                                    modifiedTime: entry.modifiedTime,
                                    flags: entry.flags,
                                    contentFormatVersion: entry.contentFormatVersion,
                                    revision: entry.revision)
    }

    func log(_ level: LogLevel, _ message: String, function: String = #function, line: Int = #line) {
        logger.log(level, category: .data, message, function: function, line: line)
    }
}

extension [EncryptedEntryEntity] {
    func updateData(with remoteEntries: [RemoteEncryptedEntry]) {
        for (index, entry) in enumerated() where index < remoteEntries.count {
            entry.update(with: remoteEntries[index])
        }
    }

    func switchToDelete() {
        for entry in self {
            entry.updateSyncState(newState: .toDelete)
        }
    }
}

extension Date {
    static var currentTimestamp: TimeInterval {
        Date.now.timeIntervalSince1970
    }
}

// swiftlint:enable line_length file_length
