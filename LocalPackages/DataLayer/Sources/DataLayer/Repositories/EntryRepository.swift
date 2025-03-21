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
import Foundation
import Models
import SimplyPersist
import SwiftData

public protocol EntryRepositoryProtocol: Sendable {
    // MARK: - Uri parsing and params from rust lib

    func entry(for uri: String) async throws -> Entry
    func export(entries: [Entry]) throws -> String
    func deserialize(serializedData: [Data]) throws -> [Entry]
    func generateCodes(entries: [Entry], time: TimeInterval) throws -> [Code]
    func createSteamEntry(params: SteamParams) throws -> Entry
    func createTotpEntry(params: TotpParams) throws -> Entry
    func serialize(entries: [Entry]) throws -> [Data]
    func getTotpParams(entry: Entry) throws -> TotpParams

    // MARK: - CRUD

    func getAllEntries() async throws -> [EntryState]
    func save(_ entries: [any IdentifiableOrderedEntry]) async throws
    func remove(_ entry: Entry) async throws
    func remove(_ entryId: String) async throws
    func removeAll() async throws
    func update(_ entry: Entry) async throws
    func updateOrder(_ entries: [any IdentifiableOrderedEntry]) async throws
}

public extension EntryRepositoryProtocol {
    func save(_ entry: any IdentifiableOrderedEntry) async throws {
        try await save([entry])
    }
}

public extension EntryRepositoryProtocol {
    func generateCodes(entries: [Entry]) throws -> [Code] {
        try generateCodes(entries: entries, time: Date().timeIntervalSince1970)
    }
}

public final class EntryRepository: Sendable, EntryRepositoryProtocol {
    private let rustClient: AuthenticatorMobileClient
    private let persistentStorage: any PersistenceServicing
    private let encryptionService: any EncryptionServicing

    public init(persistentStorage: any PersistenceServicing,
                encryptionService: any EncryptionServicing,
                rustClient: AuthenticatorMobileClient = AuthenticatorMobileClient()) {
        self.persistentStorage = persistentStorage
        self.encryptionService = encryptionService
        self.rustClient = rustClient
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

// MARK: - CRUD

public extension EntryRepository {
    func getAllEntries() async throws -> [EntryState] {
        let encryptedEntries: [EncryptedEntryEntity] = try await persistentStorage.fetch(predicate: nil,
                                                                                         sortingDescriptor: [
                                                                                             SortDescriptor(\.order)
                                                                                         ])
        return try encryptionService.decryptMany(entries: encryptedEntries)
    }

    func save(_ entries: [any IdentifiableOrderedEntry]) async throws {
        let encryptedEntries = try entries.map { try encrypt($0) }
        try await persistentStorage.batchSave(content: encryptedEntries)
    }

    func remove(_ entry: Entry) async throws {
        let predicate = #Predicate<EncryptedEntryEntity> { $0.id == entry.id }
        guard let entity: EncryptedEntryEntity = try await persistentStorage.fetchOne(predicate: predicate) else {
            return
        }
        try await persistentStorage.delete(element: entity)
    }

    func remove(_ entryId: String) async throws {
        let predicate = #Predicate<EncryptedEntryEntity> { $0.id == entryId }
        try await persistentStorage.delete(EncryptedEntryEntity.self, predicate: predicate)
    }

    func removeAll() async throws {
        try await persistentStorage.deleteAll(dataTypes: [EncryptedEntryEntity.self])
    }

    func update(_ entry: Entry) async throws {
        guard let entity = try await persistentStorage
            .fetchOne(predicate: #Predicate<EncryptedEntryEntity> { $0.id == entry.id }) else {
            return
        }
        let encryptedData = try encryptionService.encrypt(entry: entry)
        entity.updateEncryptedData(encryptedData, with: encryptionService.keyId)
        try await persistentStorage.save(data: entity)
    }

    func updateOrder(_ entries: [any IdentifiableOrderedEntry]) async throws {
        let encryptedEntries: [EncryptedEntryEntity] = try await persistentStorage.fetchAll()
        for entry in encryptedEntries {
            guard let orderedEntry = entries.first(where: { $0.id == entry.id }) else { continue }
            entry.updateOrder(newOrder: orderedEntry.order)
        }
        try await persistentStorage.batchSave(content: encryptedEntries)
    }
}

private extension EntryRepository {
    func encrypt(_ entry: any IdentifiableOrderedEntry) throws -> EncryptedEntryEntity {
        let encryptedData = try encryptionService.encrypt(entry: entry.entry)
        return EncryptedEntryEntity(id: entry.id,
                                    encryptedData: encryptedData,
                                    keyId: encryptionService.keyId,
                                    order: entry.order)
    }
}
