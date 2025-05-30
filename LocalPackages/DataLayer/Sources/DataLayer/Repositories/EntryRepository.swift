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

// swiftlint:disable line_length
public protocol EntryRepositoryProtocol: Sendable {
    // MARK: - Uri parsing and params from rust lib

    func entry(for uri: String) async throws -> Entry
    func export(entries: [Entry]) throws -> String
    func generateCodes(entries: [Entry], time: TimeInterval) throws -> [Code]
    func createSteamEntry(params: SteamParams) throws -> Entry
    func createTotpEntry(params: TotpParams) throws -> Entry
    // periphery:ignore
    func serialize(entries: [Entry]) throws -> [Data]
    // periphery:ignore
    func deserialize(serializedData: [Data]) throws -> [Entry]
    func getTotpParams(entry: Entry) throws -> TotpParams

    // MARK: - local CRUD

    func getAllLocalEntries() async throws -> [EntryState]
    func localUpsert(_ entries: [OrderedEntry]) async throws
    // periphery:ignore
    func localRemove(_ entry: Entry) async throws
    func localRemove(_ entryId: String) async throws
    // periphery:ignore
    func localRemoveAll() async throws
    func localUpdate(_ entry: OrderedEntry) async throws -> OrderedEntry?
    func localReorder(_ entries: [OrderedEntry]) async throws

    // MARK: - Remote Proton BE CRUD

    func remoteSave(entries: [OrderedEntry]) async throws -> [RemoteEncryptedEntry]
    func remoteUpdate(entry: OrderedEntry) async throws -> RemoteEncryptedEntry
    func remoteDelete(remoteEntryId: String) async throws
    func singleItemRemoteReordering(entryId: String, entries: [OrderedEntry]) async throws
    func batchRemoteReordering(entries: [OrderedEntry]) async throws
    func fetchAllRemoteEntries() async throws -> [OrderedEntry]
    func fetchRemoteEncryptionKeyOrPushLocalKey() async

    // MARK: - Full CRUD

    func completeSave(entries: [OrderedEntry]) async throws -> [RemoteEncryptedEntry]?
    func completeRemove(entry: OrderedEntry) async throws
    func completeUpdate(entry: OrderedEntry) async throws
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
    private let persistentStorage: any PersistenceServicing
    private let encryptionService: any EncryptionServicing
    private let apiClient: any APIClientProtocol
    private let userSessionManager: any UserSessionTooling
    private let store: UserDefaults
    private let logger: any LoggerProtocol

    private let entryContentFormatVersion = AppConstants.ContentFormatVersion.entry

    private let currentRemoteActiveEncryptionKeyId = AppConstants.Settings.remoteActiveEncryptionKeyId

    private var isAuthenticated: Bool {
        userSessionManager.isAuthenticated.value
    }

    private var remoteEncryptionKeyId: String? {
        store.string(forKey: currentRemoteActiveEncryptionKeyId)
    }

    public init(persistentStorage: any PersistenceServicing,
                encryptionService: any EncryptionServicing,
                apiClient: any APIClientProtocol,
                userSessionManager: any UserSessionTooling,
                store: UserDefaults,
                logger: any LoggerProtocol,
                rustClient: any AuthenticatorMobileClientProtocol = AuthenticatorMobileClient()) {
        self.persistentStorage = persistentStorage
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

    nonisolated func deserialize(serializedData: [Data]) throws -> [Entry] {
        try rustClient.deserializeEntries(serialized: serializedData).toEntries
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
                          issuer: params.issuer,
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
            return try await remoteSave(entries: entries)
        }
        return nil
    }

    func completeRemove(entry: OrderedEntry) async throws {
        if isAuthenticated, let remoteId = entry.remoteId {
            do {
                try await remoteDelete(remoteEntryId: remoteId)
            } catch {
                let entryID = entry.id
                let predicate = #Predicate<EncryptedEntryEntity> { $0.id == entryID }
                guard let entity = try? await persistentStorage.fetchOne(predicate: predicate) else {
                    log(.warning, "Cannot find local entry with ID: \(entry.id)")
                    return
                }
                entity.updateSyncState(newState: .toDelete)
                try? await persistentStorage.save(data: entity)
                return
            }
        }

        try await localRemove(entry.id)
    }

    func completeUpdate(entry: OrderedEntry) async throws {
        let orderedEntity = try await localUpdate(entry)
        if isAuthenticated, let orderedEntity {
            _ = try await remoteUpdate(entry: orderedEntity)
        }
    }

    func completeReorder(entries: [OrderedEntry]) async throws {
        try await localReorder(entries)
        if isAuthenticated {
            try await batchRemoteReordering(entries: entries)
        }
    }
}

// MARK: - CLoud / local CRUD

public extension EntryRepository {
    func getAllLocalEntries() async throws -> [EntryState] {
        log(.debug, "Fetching all local entries")
        do {
            let state = EntrySyncState.toDelete
            let predicate = #Predicate<EncryptedEntryEntity> { $0.syncState != state.rawValue }

            let encryptedEntries: [EncryptedEntryEntity] = try await persistentStorage.fetch(predicate: predicate,
                                                                                             sortingDescriptor: [
                                                                                                 SortDescriptor(\.order)
                                                                                             ])
            let entries = try encryptionService.decrypt(entries: encryptedEntries)
            log(.info, "Successfully fetched \(entries.count) local entries")
            return entries
        } catch {
            log(.error, "Failed to fetch local entries: \(error.localizedDescription)")
            throw error
        }
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

            let encryptedEntries: [EncryptedEntryEntity] = await (try? persistentStorage
                .fetch(predicate: predicate)) ?? []
            let currentLocalIds = encryptedEntries.map(\.id)
            log(.debug, "Found \(encryptedEntries.count) existing entries")

            let entitiesToUpdate = entries.filter { currentLocalIds.contains($0.id) }
            try await localUpdates(encryptedEntries: encryptedEntries, entriesToUpdate: entitiesToUpdate)

            let newEntries = entries.filter { !currentLocalIds.contains($0.id) }
            log(.debug, "Adding \(newEntries.count) new entries")

            let newEncryptedEntries = try newEntries.map { try encrypt($0, shouldEncryptWithLocalKey: true) }

            try await persistentStorage.batchSave(content: newEncryptedEntries)
            log(.info, "Successfully saved \(encryptedEntries.count) entries locally")
        } catch {
            log(.error, "Failed to save entries: \(error.localizedDescription)")
            throw error
        }
    }

    private func localUpdates(encryptedEntries: [EncryptedEntryEntity],
                              entriesToUpdate: [OrderedEntry]) async throws {
        do {
            for orderedEntry in entriesToUpdate {
                guard let keyId = orderedEntry.keyId,
                      let encryptedEntry = encryptedEntries.first(where: { $0.id == orderedEntry.id })
                else { continue }

                let encryptedData = try encryptionService.encrypt(entry: orderedEntry.entry,
                                                                  keyId: keyId,
                                                                  locally: true)
                    .encodeBase64()
                encryptedEntry.updateEncryptedData(encryptedData,
                                                   with: keyId,
                                                   remoteModifiedTime: orderedEntry.modifiedTime)
                encryptedEntry.update(with: orderedEntry)
            }

            try await persistentStorage.batchSave(content: encryptedEntries)
            log(.info, "Successfully updated \(encryptedEntries.count) entries locally")
        } catch {
            log(.error, "Failed to update entries: \(error.localizedDescription)")
            throw error
        }
    }

    func localRemove(_ entry: Entry) async throws {
        try await localRemove(entry.id)
    }

    func localRemove(_ entryId: String) async throws {
        log(.debug, "Deleting entry with id \(entryId) from local storage")
        let predicate = #Predicate<EncryptedEntryEntity> { $0.id == entryId }
        try await persistentStorage.delete(EncryptedEntryEntity.self, predicate: predicate)
        log(.info, "Successfully deleted entry \(entryId) from local storage")
    }

    func localRemoveAll() async throws {
        log(.info, "Removing all entries from local storage")
        try await persistentStorage.deleteAll(dataTypes: [EncryptedEntryEntity.self])
        log(.info, "Successfully removed all entries from local storage")
    }

    func localUpdate(_ entry: OrderedEntry) async throws -> OrderedEntry? {
        log(.debug, "Updating entry with ID: \(entry.id)")
        do {
            let entryId = entry.id
            guard let entity = try await persistentStorage
                .fetchOne(predicate: #Predicate<EncryptedEntryEntity> { $0.id == entryId }) else {
                log(.warning, "Cannot find local entry with ID: \(entry.id) for update")
                return nil
            }
            log(.debug, "Found local entry, encrypting updated data")

            let encryptedData = try encryptionService.encrypt(entry: entry.entry,
                                                              keyId: entity.keyId,
                                                              locally: true)
                .encodeBase64()
            entity.updateEncryptedData(encryptedData,
                                       with: entity.keyId,
                                       remoteModifiedTime: entry.modifiedTime)
            try await persistentStorage.save(data: entity)
            log(.info, "Successfully updated entry \(entry.id) in local storage")
            return OrderedEntry(entry: entry.entry,
                                keyId: entity.keyId,
                                remoteId: entity.remoteId,
                                order: entity.order,
                                modifiedTime: entity.modifiedTime,
                                revision: entity.revision,
                                contentFormatVersion: entryContentFormatVersion)
        } catch {
            log(.error, "Failed to update entry \(entry.id): \(error.localizedDescription)")
            throw error
        }
    }

    func localReorder(_ entries: [OrderedEntry]) async throws {
        log(.debug,
            "Updating order for \(entries.count) entries")
        do {
            let encryptedEntries: [EncryptedEntryEntity] = try await persistentStorage.fetchAll()
            log(.debug, "Found \(encryptedEntries.count) local entries for order update")

            for entry in encryptedEntries {
                guard let orderedEntry = entries.first(where: { $0.id == entry.id }) else { continue }
                entry.updateOrder(newOrder: orderedEntry.order)
            }

            try await persistentStorage.batchSave(content: encryptedEntries)
            log(.info, "Successfully saved updated order to local storage")
        } catch {
            log(.error, "Failed to update entry order: \(error.localizedDescription)")
            throw error
        }
    }
}

// MARK: - Remote proton BE CRUD for entries

public extension EntryRepository {
    func remoteSave(entries: [OrderedEntry]) async throws -> [RemoteEncryptedEntry] {
        log(.debug, "Saving \(entries.count) entries to remote")

        guard let remoteEncryptionKeyId else {
            log(.error, "No remote key ID registered for remote save")
            throw AuthError.crypto(.missingRemoteEncryptionKey)
        }

        do {
            let encryptedEntriesRequest = try entries.map { entry in
                let encryptedEntry = try encrypt(entry, shouldEncryptWithLocalKey: false)
                return StoreEntryRequest(authenticatorKeyID: remoteEncryptionKeyId,
                                         content: encryptedEntry.encryptedData,
                                         contentFormatVersion: entryContentFormatVersion)
            }
            let request = StoreEntriesRequest(entries: encryptedEntriesRequest)
            let result = try await apiClient.storeEntries(request: request)
            log(.info, "Successfully stored \(result.count) entries on remote")

            let idsToFetch: [String] = entries.map(\.id)
            let predicate = #Predicate<EncryptedEntryEntity> { entity in
                idsToFetch.contains(entity.id)
            }
            let encryptedEntries: [EncryptedEntryEntity] = await (try? persistentStorage
                .fetch(predicate: predicate)) ?? []
            encryptedEntries.updateData(with: result)
            try await persistentStorage.batchSave(content: encryptedEntries)
            return result
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
            let encryptedEntry = try encrypt(entry, shouldEncryptWithLocalKey: false)
            let request = UpdateEntryRequest(authenticatorKeyID: remoteEncryptionKeyId,
                                             content: encryptedEntry.encryptedData,
                                             contentFormatVersion: entryContentFormatVersion,
                                             lastRevision: entry.revision)

            let result = try await apiClient.update(entryId: remoteId, request: request)

            let entityId = entry.id
            if let localEntity = try await persistentStorage
                .fetchOne(predicate: #Predicate<EncryptedEntryEntity> { $0.id == entityId }) {
                log(.debug, "Found local entry, and updating it with remote entry data")
                localEntity.update(with: result)
                try await persistentStorage.save(data: localEntity)
            }

            log(.info, "Successfully updated entry with id \(remoteId) on remote")
            return result
        } catch {
            log(.error, "Failed to update entry with id \(remoteId) on remote: \(error.localizedDescription)")
            throw error
        }
    }

    func remoteDelete(remoteEntryId: String) async throws {
        log(.debug, "Deleting entry \(remoteEntryId) from remote")
        do {
            _ = try await apiClient.delete(entryId: remoteEntryId)
            log(.info, "Successfully deleted entry with id\(remoteEntryId) from remote")
        } catch {
            log(.error,
                "Failed to delete entry with id \(remoteEntryId) from remote: \(error.localizedDescription)")
            throw error
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
            let encryptedEntries = try await apiClient.getEntries()
            log(.debug, "Retrieved \(encryptedEntries.count) encrypted entries from remote")

            var entries: [OrderedEntry] = []
            for (index, encryptedEntry) in encryptedEntries.enumerated() {
                if !encryptionService.contains(keyId: encryptedEntry.authenticatorKeyID) {
                    log(.debug,
                        "Missing key \(encryptedEntry.authenticatorKeyID) for entry \(encryptedEntry.entryID), fetching keys")
                    await fetchRemoteEncryptionKeyOrPushLocalKey()
                }
                let decryptedEntry = try encryptionService.decryptRemoteData(encryptedData: encryptedEntry)

                var syncState = EntrySyncState.unsynced
                let entityId = decryptedEntry.id
                if await (try? persistentStorage
                    .fetchOne(predicate: #Predicate<EncryptedEntryEntity> { $0.id == entityId })) != nil {
                    syncState = .synced
                }
                let orderedEntry = OrderedEntry(entry: decryptedEntry,
                                                keyId: encryptedEntry.authenticatorKeyID,
                                                remoteId: encryptedEntry.entryID,
                                                order: index,
                                                syncState: syncState,
                                                creationDate: Double(encryptedEntry.createTime),
                                                modifiedTime: Double(encryptedEntry.modifyTime),
                                                flags: encryptedEntry.flags,
                                                revision: encryptedEntry.revision,
                                                contentFormatVersion: encryptedEntry.contentFormatVersion)
                entries.append(orderedEntry)
            }
            log(.info, "Successfully fetched and decrypted \(entries.count) entries from remote")

            return entries
        } catch {
            log(.error, "Failed to fetch entries from remote: \(error.localizedDescription)")
            throw error
        }
    }
}

// MARK: - Remote util functions for encryption key

extension EntryRepository {
    // This function fetches check if a remtoe encryption key exists for the user.
    // If a key exists it saves it's id in the store and return.
    // Otherwise it tries and push the local encryption key to the BE
    public func fetchRemoteEncryptionKeyOrPushLocalKey() async {
        do {
            log(.info, "Initiating fetch or push of encryption keys")
            let currentEncryptionKey: RemoteEncryptedKey?

            if let remoteEncryptionKey = try await fetchAndSaveRemoteKeys() {
                log(.info, "Remote key already exists, with id: \(remoteEncryptionKey.keyID)")
                currentEncryptionKey = remoteEncryptionKey
            } else {
                log(.debug, "No remote key found, sending local encryption key")
                currentEncryptionKey = try await sendLocalEncryptionKey()
            }

            store.set(currentEncryptionKey?.keyID, forKey: currentRemoteActiveEncryptionKeyId)
            log(.info,
                "Stored remote key ID: \(currentEncryptionKey?.keyID ?? "unknown")")
        } catch {
            log(.error, "Failed in fetchOrPushLocalKey: \(error.localizedDescription)")
        }
    }

    private func sendLocalEncryptionKey() async throws -> RemoteEncryptedKey? {
        log(.debug, "Sending local encryption key to remote")

        guard userSessionManager.isAuthenticated.value else {
            log(.warning, "Cannot send local encryption key: user not authenticated")
            return nil
        }

        do {
            let key = try encryptionService.localEncryptionKey
            log(.debug, "Encrypting local encryption key for remote storage")
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

    // This function fetches current user remotly stored keys
    // It then decrypts and saved all missing keys in the `encryptionService` keychain
    // It then returns the current remote encryption key linked to the active user key (Should always be a maximum
    // of one key)
    private func fetchAndSaveRemoteKeys() async throws -> RemoteEncryptedKey? {
        log(.debug, "Fetching remote encryption keys")
        do {
            let encryptedKeysData = try await apiClient.getKeys()
            log(.debug, "Retrieved \(encryptedKeysData.count) remote encryption keys")

            var newKeysAdded = 0
            for encryptedKeyData in encryptedKeysData
                where !encryptionService.contains(keyId: encryptedKeyData.keyID) {
                log(.debug, "Processing new key with ID: \(encryptedKeyData.keyID)")

                let keyDecrypted: Data = try userSessionManager.userKeyDecrypt(key: encryptedKeyData)
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
                 shouldEncryptWithLocalKey: Bool) throws -> EncryptedEntryEntity {
        let encryptionKeyId: String
        if shouldEncryptWithLocalKey {
            encryptionKeyId = encryptionService.localEncryptionKeyId
        } else {
            if let remoteEncryptionKeyId {
                encryptionKeyId = remoteEncryptionKeyId
            } else {
                throw AuthError.crypto(.missingRemoteEncryptionKey)
            }
        }

        let remoteId = entry.remoteId ?? ""

        let encryptedData = try encryptionService.encrypt(entry: entry.entry,
                                                          keyId: encryptionKeyId,
                                                          locally: shouldEncryptWithLocalKey)
            .encodeBase64()
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
}

// swiftlint:enable line_length

extension Date {
    static var currentTimestamp: TimeInterval {
        Date.now.timeIntervalSince1970
    }
}
