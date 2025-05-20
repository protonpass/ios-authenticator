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

    // MARK: - CRUD

    func getAllLocalEntries() async throws -> [EntryState]
    func save(_ entries: [any IdentifiableOrderedEntry], remotePush: Bool) async throws
    // periphery:ignore
    func remove(_ entry: Entry, remotePush: Bool) async throws
    func remove(_ entryId: String, remotePush: Bool) async throws
    // periphery:ignore
    func removeAll() async throws
    func update(_ entry: Entry, remotePush: Bool) async throws
    func updateOrder(entryIdMoved: String?,
                     _ entries: [any IdentifiableOrderedEntry],
                     remotePush: Bool) async throws

    // MARK: - Proton BE

    func fetchAndSaveRemoteKeys() async throws
    func fetchRemoteEntries() async throws -> [OrderedEntry]
}

public extension EntryRepositoryProtocol {
    func save(_ entry: any IdentifiableOrderedEntry, remotePush: Bool) async throws {
        try await save([entry], remotePush: remotePush)
    }
}

public extension EntryRepositoryProtocol {
    func generateCodes(entries: [Entry]) throws -> [Code] {
        try generateCodes(entries: entries, time: Date().timeIntervalSince1970)
    }
}

// swiftlint:disable:next todo
// TODO: take into account user settings for backup sync local data

public final class EntryRepository: Sendable, EntryRepositoryProtocol, LoggingImplemented {
    private let rustClient: AuthenticatorMobileClientProtocol
    private let persistentStorage: any PersistenceServicing
    private let encryptionService: any EncryptionServicing
    private let apiClient: any APIClientProtocol
    private let userSessionManager: any UserSessionTooling
    private let store: UserDefaults
    let logger: any LoggerProtocol

    private let entryContentFormatVersion = AppConstants.ContentFormatVersion.entry
    private nonisolated(unsafe) var cancellables: Set<AnyCancellable> = []

    private let remoteKeyId = AppConstants.Settings.hasPushedEncryptionKey

    private var isAuthenticated: Bool {
        userSessionManager.isAuthenticated.value
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

        log(.info, "Entry Repository initialized")

        userSessionManager.isAuthenticated
            .sink { [weak self] authStatus in
                guard let self, authStatus else { return }
                log(.info, "User authentication status changed to: \(authStatus)")
                fetchOrPushLocalKey()
            }
            .store(in: &cancellables)
    }
}

// MARK: - Uri parsing and params from rust lib

public extension EntryRepository {
    func entry(for uri: String) async throws -> Entry {
        try rustClient.entryFromUri(uri: uri).toEntry
    }

    func export(entries: [Entry]) throws -> String {
        try rustClient.exportEntries(entries: entries.toRustEntries)
    }

    func deserialize(serializedData: [Data]) throws -> [Entry] {
        try rustClient.deserializeEntries(serialized: serializedData).toEntries
    }

    func generateCodes(entries: [Entry], time: TimeInterval) throws -> [Code] {
        try rustClient.generateCodes(entries: entries.toRustEntries, time: UInt64(time)).toCodes
    }

    func createSteamEntry(params: SteamParams) throws -> Entry {
        try rustClient.newSteamEntryFromParams(params: params.toRustParams).toEntry
    }

    func createTotpEntry(params: TotpParams) throws -> Entry {
        try rustClient.newTotpEntryFromParams(params: params.toRustParams).toEntry
    }

    func serialize(entries: [Entry]) throws -> [Data] {
        try rustClient.serializeEntries(entries: entries.toRustEntries)
    }

    func getTotpParams(entry: Entry) throws -> TotpParams {
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

    func save(_ entries: [any IdentifiableOrderedEntry], remotePush: Bool) async throws {
        log(.debug, "Saving \(entries.count) entries with remotePush: \(remotePush)")
        do {
            // Fetch entities that already exist for the ids (as we cannot leverage swiftdata .unique with icloud)
            // to remove duplicates.
            let idsToFetch: [String] = entries.map(\.id)
            let predicate = #Predicate<EncryptedEntryEntity> { entity in
                idsToFetch.contains(entity.id)
            }

            var encryptedEntries: [EncryptedEntryEntity] = try await persistentStorage.fetch(predicate: predicate)
            let currentLocalIds = encryptedEntries.map(\.id)
            log(.debug, "Found \(encryptedEntries.count) existing entries")

            let newEntries = entries.filter { !currentLocalIds.contains($0.id) }
            log(.debug, "Adding \(newEntries.count) new entries")

            encryptedEntries += try newEntries.map { try encrypt($0) }

            try await persistentStorage.batchSave(content: encryptedEntries)
            log(.info, "Successfully saved \(encryptedEntries.count) entries locally")

            if remotePush, isAuthenticated {
                log(.debug, "Pushing \(encryptedEntries.count) entries to remote")
                let remoteEntries = try await remoteSave(encryptedEntries)
                encryptedEntries.updateSyncState(.synced, remoteEntries: remoteEntries)
                try await persistentStorage.batchSave(content: encryptedEntries)
                log(.info, "Successfully pushed \(remoteEntries.count) entries to remote")
            }
        } catch {
            log(.error, "Failed to save entries: \(error.localizedDescription)")
            throw error
        }
    }

    func remove(_ entry: Entry, remotePush: Bool) async throws {
        try await remove(entry.id, remotePush: remotePush)
    }

    func remove(_ entryId: String, remotePush: Bool) async throws {
        log(.debug, "Removing entry with ID: \(entryId), remotePush: \(remotePush)")

        if isAuthenticated {
            guard let entity = try? await persistentStorage
                .fetchOne(predicate: #Predicate<EncryptedEntryEntity> { $0.id == entryId }) else {
                log(.warning, "Cannot find local entry with ID: \(entryId)")
                return
            }
            do {
                log(.debug, "Attempting to delete entry \(entryId) from remote")
                try await remoteDelete(entryId: entity.remoteId)
                log(.info, "Successfully deleted entry \(entryId) from remote")
            } catch {
                log(.warning, "Failed to delete entry \(entryId) from remote: \(error.localizedDescription)")
                log(.debug, "Marking entry \(entryId) for deletion on next sync")
                entity.updateSyncState(newState: .toDelete)
                try? await persistentStorage.save(data: entity)
                return
            }
        }
        log(.debug, "Deleting entry \(entryId) from local storage")
        let predicate = #Predicate<EncryptedEntryEntity> { $0.id == entryId }
        try await persistentStorage.delete(EncryptedEntryEntity.self, predicate: predicate)
        log(.info, "Successfully deleted entry \(entryId) from local storage")
    }

    // swiftlint:disable:next todo
    // TODO: need maybe remote delete all ?
    func removeAll() async throws {
        log(.info, "Removing all entries from local storage")
        try await persistentStorage.deleteAll(dataTypes: [EncryptedEntryEntity.self])
        log(.info, "Successfully removed all entries from local storage")
    }

    func update(_ entry: Entry, remotePush: Bool) async throws {
        log(.debug, "Updating entry with ID: \(entry.id), remotePush: \(remotePush)")
        do {
            guard let entity = try await persistentStorage
                .fetchOne(predicate: #Predicate<EncryptedEntryEntity> { $0.id == entry.id }) else {
                log(.warning, "Cannot find local entry with ID: \(entry.id) for update")
                return
            }
            log(.debug, "Found local entry, encrypting updated data")

            let encryptedData = try encryptionService.encrypt(entry: entry, keyId: entity.keyId)
            entity.updateEncryptedData(encryptedData, with: encryptionService.keyId)
            try await persistentStorage.save(data: entity)
            log(.info, "Successfully updated entry \(entry.id) in local storage")

            if remotePush, isAuthenticated, entity.isSynced {
                log(.debug, "Updating entry \(entry.id) on remote with revision \(entity.revision)")

                do {
                    try await remoteUpdate(entryId: entity.remoteId,
                                           encryptedUpdatedEntry: encryptedData,
                                           revision: entity.revision)
                    log(.info, "Successfully updated entry \(entry.id) on remote")
                } catch {
                    log(.error, "Failed to update entry \(entry.id) remotely: \(error.localizedDescription)")
                }
            }
        } catch {
            log(.error, "Failed to update entry \(entry.id): \(error.localizedDescription)")
            throw error
        }
    }

    // swiftlint:disable:next todo
    // TODO: maybe imeplement factionnal index for ordering if the current reorder if to heavy?
    func updateOrder(entryIdMoved: String?,
                     _ entries: [any IdentifiableOrderedEntry],
                     remotePush: Bool) async throws {
        log(.debug,
            "Updating order for \(entries.count) entries, moved entry ID: \(entryIdMoved ?? "none")")
        do {
            let encryptedEntries: [EncryptedEntryEntity] = try await persistentStorage.fetchAll()
            log(.debug, "Found \(encryptedEntries.count) local entries for order update")

            for entry in encryptedEntries {
                guard let orderedEntry = entries.first(where: { $0.id == entry.id }) else { continue }
                entry.updateOrder(newOrder: orderedEntry.order)
            }

            try await persistentStorage.batchSave(content: encryptedEntries)
            log(.info, "Successfully saved updated order to local storage")

            // swiftlint:disable:next todo
            // TODO: maybe check if the moved item is synched and maybe have a multi order function
            if isAuthenticated, remotePush, let entryIdMoved {
                log(.debug, "Updating order for entry \(entryIdMoved) on remote")
                try await remoteOrdering(entryId: entryIdMoved, entries: encryptedEntries)
                log(.info, "Successfully updated order for entry \(entryIdMoved) on remote")
            }
        } catch {
            log(.error, "Failed to update entry order: \(error.localizedDescription)")
            throw error
        }
    }
}

// MARK: - Remote proton BE CRUD

public extension EntryRepository {
    func remoteSave(_ encryptedEntries: [EncryptedEntryEntity]) async throws -> [RemoteEncryptedEntry] {
        log(.debug, "Saving \(encryptedEntries.count) entries to remote")

        guard let remoteKeyId = store.string(forKey: remoteKeyId) else {
            log(.error, "No remote key ID registered for remote save")
            // swiftlint:disable:next todo
            // TODO: maybe return error
            return []
        }

        do {
            let encryptedEntriesRequest = encryptedEntries.map { entry in
                StoreEntryRequest(authenticatorKeyID: remoteKeyId,
                                  content: entry.encryptedData.encodeBase64(),
                                  contentFormatVersion: entryContentFormatVersion)
            }
            let request = StoreEntriesRequest(entries: encryptedEntriesRequest)
            let result = try await apiClient.storeEntries(request: request)
            log(.info, "Successfully stored \(result.count) entries on remote")
            return result
        } catch {
            log(.error, "Failed to store entries on remote: \(error.localizedDescription)")
            throw error
        }
    }

    func remoteUpdate(entryId: String, encryptedUpdatedEntry: Data, revision: Int) async throws {
        log(.debug, "Updating entry \(entryId) on remote with revision \(revision)")

        guard let remoteKey = store.string(forKey: remoteKeyId) else {
            log(.error, "No remote key ID registered for remote update")
            return
        }
        do {
            let request = UpdateEntryRequest(authenticatorKeyID: remoteKey,
                                             content: encryptedUpdatedEntry.encodeBase64(),
                                             contentFormatVersion: entryContentFormatVersion,
                                             lastRevision: revision)

            _ = try await apiClient.update(entryId: entryId, request: request)
            log(.info, "Successfully updated entry with id \(entryId) on remote")
        } catch {
            log(.error, "Failed to update entry with id \(entryId) on remote: \(error.localizedDescription)")
            throw error
        }
    }

    func remoteDelete(entryId: String) async throws {
        log(.debug, "Deleting entry \(entryId) from remote")

        do {
            _ = try await apiClient.delete(entryId: entryId)
            log(.info, "Successfully deleted entry with id\(entryId) from remote")
        } catch {
            log(.error, "Failed to delete entry with id \(entryId) from remote: \(error.localizedDescription)")
            throw error
        }
    }

    func remoteOrdering(entryId: String, entries: [EncryptedEntryEntity]) async throws {
        log(.debug, "Updating order for entry \(entryId) on remote")

        var afterID: String?
        if let index = entries.firstIndex(where: { $0.id == entryId }), index > 0 {
            afterID = entries[index - 1].remoteId
            log(.debug, "Entry will be positioned after entry with remote ID: \(afterID ?? "nil")")
        }

        do {
            let request = NewOrderRequest(afterID: afterID)
            _ = try await apiClient.changeOrder(entryId: entryId, request: request)
            log(.info, "Successfully updated order for entry \(entryId) on remote")
        } catch {
            log(.error, "Failed to update order for entry \(entryId) on remote: \(error.localizedDescription)")
            throw error
        }
    }

    func fetchAndSaveRemoteKeys() async throws {
        log(.debug, "Fetching remote encryption keys")
        do {
            let encryptedKeysData = try await apiClient.getKeys()
            log(.debug, "Retrieved \(encryptedKeysData.count) remote encryption keys")

            // Check if there is an rust auth key link to active user key
            guard let currentEncryptionKeyId = try userSessionManager
                .getKeyLinkedToActiveUserKey(remoteKeyIds: encryptedKeysData.map(\.userKeyID)) else {
                log(.warning, "No encryption key linked to active user key found")
                return
            }

            store.set(currentEncryptionKeyId, forKey: remoteKeyId)
            log(.info, "Set current encryption key ID: \(currentEncryptionKeyId)")

            var newKeysAdded = 0
            for encryptedKeyData in encryptedKeysData
                where !encryptionService.contains(keyId: encryptedKeyData.keyID) {
                log(.debug, "Processing new key with ID: \(encryptedKeyData.keyID)")

                let keyDecrypted: Data = try userSessionManager.userKeyDecrypt(keyId: encryptedKeyData.keyID,
                                                                               data: encryptedKeyData.key)
                try encryptionService.saveProtonKey(keyId: encryptedKeyData.keyID, key: keyDecrypted)
                newKeysAdded += 1
            }
            log(.info, "Successfully processed remote keys, added \(newKeysAdded) new keys")
        } catch {
            log(.error, "Failed to fetch and save remote keys: \(error.localizedDescription)")
            throw error
        }
    }

    func sendLocalEncryptionKey() async throws -> RemoteEncryptedKey? {
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
            log(.info, "Successfully stored local encryption key on remote with ID: \(result.keyID)")
            return result
        } catch {
            log(.error, "Failed to send local encryption key to remote: \(error.localizedDescription)")
            throw error
        }
    }

    func fetchRemoteEntries() async throws -> [OrderedEntry] {
        log(.debug, "Fetching entries from remote")

        do {
            let encryptedEntries = try await apiClient.getEntries()
            log(.debug, "Retrieved \(encryptedEntries.count) encrypted entries from remote")

            var entries: [OrderedEntry] = []
            for (index, encryptedEntry) in encryptedEntries.enumerated() {
                if !encryptionService.contains(keyId: encryptedEntry.authenticatorKeyID) {
                    log(.debug,
                        "Missing key \(encryptedEntry.authenticatorKeyID) for entry \(encryptedEntry.entryID), fetching keys")
                    try await fetchAndSaveRemoteKeys()
                }
                let decryptedEntry = try encryptionService.decryptProtonData(encryptedData: encryptedEntry)
                let orderedEntry = OrderedEntry(entry: decryptedEntry,
                                                keyId: encryptedEntry.authenticatorKeyID,
                                                remoteId: encryptedEntry.entryID,
                                                order: index,
                                                syncState: .synced,
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

private extension EntryRepository {
    func encrypt(_ entry: any IdentifiableOrderedEntry) throws -> EncryptedEntryEntity {
        let encryptedData = try encryptionService.encrypt(entry: entry.entry,
                                                          keyId: (entry as? OrderedEntry)?
                                                              .keyId ?? encryptionService.keyId)
        return EncryptedEntryEntity(id: (entry as? OrderedEntry)?.id ?? entry.id,
                                    encryptedData: encryptedData,
                                    remoteId: ((entry as? OrderedEntry)?.remoteId) ?? "",
                                    keyId: (entry as? OrderedEntry)?.keyId ?? encryptionService.keyId,
                                    order: entry.order,
                                    syncState: entry.syncState,
                                    creationDate: (entry as? OrderedEntry)?.creationDate ?? Date.now
                                        .timeIntervalSince1970,
                                    modifiedTime: (entry as? OrderedEntry)?.modifiedTime ?? Date.now
                                        .timeIntervalSince1970,
                                    flags: (entry as? OrderedEntry)?.flags ?? 0,
                                    contentFormatVersion: (entry as? OrderedEntry)?
                                        .contentFormatVersion ?? entryContentFormatVersion,
                                    revision: (entry as? OrderedEntry)?.revision ?? 0)
    }

    func fetchOrPushLocalKey() {
        Task { [weak self] in
            guard let self else { return }
            do {
                log(.info, "Initiating fetch or push of encryption keys")

                try await fetchAndSaveRemoteKeys()
                log(.debug,
                    "Completed fetchAndSaveRemoteKeys, stored key: \(store.string(forKey: remoteKeyId) ?? "nil")")

                guard store.string(forKey: remoteKeyId) == nil else {
                    log(.debug, "Remote key already exists, no need to push local key")
                    return
                }
                log(.debug, "No remote key found, sending local encryption key")

                let remoteKeyInfo = try await sendLocalEncryptionKey()
                store.set(remoteKeyInfo?.keyID, forKey: remoteKeyId)
                log(.info,
                    "Successfully pushed local encryption key, stored remote key ID: \(remoteKeyInfo?.keyID ?? "unknown")")
            } catch {
                log(.error, "Failed in fetchOrPushLocalKey: \(error.localizedDescription)")
            }
        }
    }
}

extension [EncryptedEntryEntity] {
    func updateSyncState(_ newState: EntrySyncState, remoteEntries: [RemoteEncryptedEntry]) {
        for (index, entry) in self.enumerated() {
            entry.updateSyncState(newState: newState)
            if remoteEntries.count > index {
                entry.updateRemoteId(remoteEntries[index].entryID)
            }
        }
    }
}

// swiftlint:enable line_length
