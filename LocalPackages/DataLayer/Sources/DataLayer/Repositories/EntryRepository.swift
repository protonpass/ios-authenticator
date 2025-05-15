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
        try await save([entry], remotePush: false)
    }
}

public extension EntryRepositoryProtocol {
    func generateCodes(entries: [Entry]) throws -> [Code] {
        try generateCodes(entries: entries, time: Date().timeIntervalSince1970)
    }
}

// swiftlint:disable:next todo
// TODO: take into account user settings for backup sync local data

public final class EntryRepository: Sendable, EntryRepositoryProtocol {
    private let rustClient: AuthenticatorMobileClientProtocol
    private let persistentStorage: any PersistenceServicing
    private let encryptionService: any EncryptionServicing
    private let apiClient: any APIClientProtocol
    private let userSessionManager: any UserSessionTooling
    private let store: UserDefaults

    private let entryContentFormatVersion = AppConstants.ContentFormatVersion.entry
    private nonisolated(unsafe) var cancellables: Set<AnyCancellable> = []

    private let savingKeyId = AppConstants.Settings.hasPushedEncryptionKey

    private var isAuthenticated: Bool {
        userSessionManager.isAuthenticated.value
    }

    public init(persistentStorage: any PersistenceServicing,
                encryptionService: any EncryptionServicing,
                apiClient: any APIClientProtocol,
                userSessionManager: any UserSessionTooling,
                store: UserDefaults,
                rustClient: any AuthenticatorMobileClientProtocol = AuthenticatorMobileClient()) {
        self.persistentStorage = persistentStorage
        self.encryptionService = encryptionService
        self.apiClient = apiClient
        self.userSessionManager = userSessionManager
        self.rustClient = rustClient
        self.store = store

        store.register(defaults: [
            savingKeyId: false
        ])

        userSessionManager.isAuthenticated
            .sink { [weak self] authStatus in
                guard let self, authStatus else { return }
                pushLocalKey()
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
        let state = EntrySyncState.toDelete
        let predicate = #Predicate<EncryptedEntryEntity> { $0.syncState != state.rawValue }

        let encryptedEntries: [EncryptedEntryEntity] = try await persistentStorage.fetch(predicate: predicate,
                                                                                         sortingDescriptor: [
                                                                                             SortDescriptor(\.order)
                                                                                         ])
        return try encryptionService.decrypt(entries: encryptedEntries)
    }

    func save(_ entries: [any IdentifiableOrderedEntry], remotePush: Bool) async throws {
        let encryptedEntries = try entries.map { try encrypt($0) }

        if remotePush, isAuthenticated {
            try await remoteSave(encryptedEntries)
            encryptedEntries.updateSyncState(.synced)
        }
        try await persistentStorage.batchSave(content: encryptedEntries)
    }

    func remove(_ entry: Entry, remotePush: Bool) async throws {
        try await remove(entry.id, remotePush: remotePush)
    }

    func remove(_ entryId: String, remotePush: Bool) async throws {
        if isAuthenticated {
            do {
                try await remoteDelete(entryId: entryId)
            } catch {
                guard let entity = try? await persistentStorage
                    .fetchOne(predicate: #Predicate<EncryptedEntryEntity> { $0.id == entryId }) else {
                    return
                }
                entity.updateSyncState(newState: .toDelete)
                try? await persistentStorage.save(data: entity)
                return
            }
        }
        let predicate = #Predicate<EncryptedEntryEntity> { $0.id == entryId }
        try await persistentStorage.delete(EncryptedEntryEntity.self, predicate: predicate)
    }

    func removeAll() async throws {
        try await persistentStorage.deleteAll(dataTypes: [EncryptedEntryEntity.self])
    }

    func update(_ entry: Entry, remotePush: Bool) async throws {
        guard let entity = try await persistentStorage
            .fetchOne(predicate: #Predicate<EncryptedEntryEntity> { $0.id == entry.id }) else {
            return
        }
        let encryptedData = try encryptionService.encrypt(entry: entry)
        if remotePush, isAuthenticated, entity.isSynced {
            try await remoteUpdate(entryId: entity.id,
                                   encryptedUpdatedEntry: encryptedData,
                                   revision: entity.revision)
        }
        entity.updateEncryptedData(encryptedData, with: encryptionService.keyId)
        try await persistentStorage.save(data: entity)
    }

    func updateOrder(entryIdMoved: String?,
                     _ entries: [any IdentifiableOrderedEntry],
                     remotePush: Bool) async throws {
        let encryptedEntries: [EncryptedEntryEntity] = try await persistentStorage.fetchAll()
        for entry in encryptedEntries {
            guard let orderedEntry = entries.first(where: { $0.id == entry.id }) else { continue }
            entry.updateOrder(newOrder: orderedEntry.order)
        }
        // swiftlint:disable:next todo
        // TODO: maybe check if the moved item is synched and maybe have a multi order function
        if isAuthenticated, remotePush, let entryIdMoved {
            try await remoteOrdering(entryId: entryIdMoved, entries: encryptedEntries)
        }
        try await persistentStorage.batchSave(content: encryptedEntries)
    }
}

// MARK: - Remote proton BE CRUD

public extension EntryRepository {
    func remoteSave(_ encryptedEntries: [EncryptedEntryEntity]) async throws {
        let encryptedEntriesRequest = encryptedEntries.map { entry in
            StoreEntryRequest(authenticatorKeyID: encryptionService.keyId,
                              content: entry.encryptedData.encodeBase64(),
                              contentFormatVersion: entryContentFormatVersion)
        }
        let request = StoreEntriesRequest(entries: encryptedEntriesRequest)
        _ = try await apiClient.storeEntries(request: request)
    }

    func remoteUpdate(entryId: String, encryptedUpdatedEntry: Data, revision: Int) async throws {
        let request = UpdateEntryRequest(authenticatorKeyID: encryptionService.keyId,
                                         content: encryptedUpdatedEntry.encodeBase64(),
                                         contentFormatVersion: entryContentFormatVersion,
                                         lastRevision: revision)

        _ = try await apiClient.update(entryId: entryId, request: request)
    }

    func remoteDelete(entryId: String) async throws {
        _ = try await apiClient.delete(entryId: entryId)
    }

    func remoteOrdering(entryId: String, entries: [EncryptedEntryEntity]) async throws {
        var afterID: String?
        if let index = entries.firstIndex(where: { $0.id == entryId }), index > 0 {
            afterID = entries[index - 1].id
        }
        let request = NewOrderRequest(afterID: afterID)
        _ = try await apiClient.changeOrder(entryId: entryId, request: request)
    }

    func fetchAndSaveRemoteKeys() async throws {
//        guard userSessionManager.isAuthenticated.value else {
//            return
//        }

        let encryptedKeysData = try await apiClient.getKeys()

        for encryptedKeyData in encryptedKeysData
            where !encryptionService.contains(keyId: encryptedKeyData.keyID) {
            let keyDataDecrypted: Data = try userSessionManager.userKeyDecrypt(keyId: encryptedKeyData.keyID,
                                                                               data: encryptedKeyData.key)

            try encryptionService.saveProtonKey(keyId: encryptedKeyData.keyID, key: keyDataDecrypted)
        }
    }

    func sendLocalEncryptionKey() async throws {
        guard userSessionManager.isAuthenticated.value else {
            return
        }
        let key = try encryptionService.localEncryptionKey
        let encryptedKey = try userSessionManager.userKeyEncrypt(object: key)
        _ = try await apiClient.storeKey(encryptedKey: encryptedKey)
    }

    func fetchRemoteEntries() async throws -> [OrderedEntry] {
//        guard userSessionManager.isAuthenticated.value else {
//            return nil
//        }
        let encryptedEntries = try await apiClient.getEntries()

        var entries: [OrderedEntry] = []
        for (index, encryptedEntry) in encryptedEntries.enumerated() {
            if !encryptionService.contains(keyId: encryptedEntry.authenticatorKeyID) {
                try await fetchAndSaveRemoteKeys()
            }
            let decryptedEntry = try encryptionService.decryptProtonData(encryptedData: encryptedEntry)
            let orderedEntry = OrderedEntry(entry: decryptedEntry,
                                            order: index,
                                            syncState: .synced,
                                            creationDate: Double(encryptedEntry.createTime),
                                            modifiedTime: Double(encryptedEntry.modifyTime),
                                            flags: encryptedEntry.flags,
                                            revision: encryptedEntry.revision,
                                            contentFormatVersion: encryptedEntry.contentFormatVersion)
            entries.append(orderedEntry)
        }
        return entries
    }
}

private extension EntryRepository {
    func encrypt(_ entry: any IdentifiableOrderedEntry) throws -> EncryptedEntryEntity {
        let encryptedData = try encryptionService.encrypt(entry: entry.entry)
        return EncryptedEntryEntity(id: entry.id,
                                    encryptedData: encryptedData,
                                    keyId: encryptionService.keyId,
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

    func pushLocalKey() {
        guard store.bool(forKey: savingKeyId) == false else {
            return
        }
        Task { [weak self] in
            guard let self else { return }
            do {
                try await sendLocalEncryptionKey()
                store.set(true, forKey: savingKeyId)
            } catch {
                print(error)
            }
        }
    }
}

extension [EncryptedEntryEntity] {
    func updateSyncState(_ newState: EntrySyncState) {
        for entry in self {
            entry.updateSyncState(newState: newState)
        }
    }
}
