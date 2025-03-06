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

    func getAllEntries() async throws -> [Entry]
    func save(_ entry: Entry) async throws
    func save(_ entries: [Entry]) async throws
    func remove(_ entry: Entry) async throws
    func remove(_ entryId: String) async throws
    func removeAll() async throws
    func update(_ entry: Entry) async throws
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
        try rustClient.exportEntries(entries: entries.toAuthenticatorEntries)
    }

    func deserialize(serializedData: [Data]) throws -> [Entry] {
        try rustClient.deserializeEntries(serialized: serializedData).toEntries
    }

    func generateCodes(entries: [Entry],
                       time: TimeInterval = Date().timeIntervalSince1970) throws -> [Code] {
        try rustClient.generateCodes(entries: entries.toAuthenticatorEntries, time: UInt64(time))
            .toCodes
    }

    func createSteamEntry(params: SteamParams) throws -> Entry {
        try rustClient
            .newSteamEntryFromParams(params: params.toAuthenticatorEntrySteamCreateParameters).toEntry
    }

    func createTotpEntry(params: TotpParams) throws -> Entry {
        try rustClient.newTotpEntryFromParams(params: params.toAuthenticatorEntryTotpCreateParameters)
            .toEntry
    }

    func serialize(entries: [Entry]) throws -> [Data] {
        try rustClient.serializeEntries(entries: entries.toAuthenticatorEntries)
    }

    func getTotpParams(entry: Entry) throws -> TotpParams {
        let params = try rustClient.getTotpParams(entry: entry.toAuthenticatorEntryModel)

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
    func getAllEntries() async throws -> [Entry] {
        let encryptedEntries: [EncryptedEntryEntity] = try await persistentStorage.fetchAll()

        return try encryptedEntries.map { encryptedEntry in
            var entry = try encryptionService.decrypt(entry: encryptedEntry.encryptedData)
            entry.id = encryptedEntry.id
            return entry
        }
    }

    func save(_ entry: Entry) async throws {
        let entity = try encrypt(entry)
        try await persistentStorage.save(data: entity)
    }

    func save(_ entries: [Entry]) async throws {
        let entities: [EncryptedEntryEntity] = try entries.map {
            try encrypt($0)
        }

        try await persistentStorage.batchSave(content: entities)
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
        guard let entity: EncryptedEntryEntity = try await persistentStorage.fetchOne(predicate: predicate) else {
            return
        }
        try await persistentStorage.delete(element: entity)
    }

    func removeAll() async throws {
        try await persistentStorage.deleteAll(dataTypes: [EncryptedEntryEntity.self])
    }

    func update(_ entry: Entry) async throws {
        guard let entity = try await persistentStorage
            .fetchOne(predicate: #Predicate<EncryptedEntryEntity> { $0.id == entry.id }) else {
            return
        }
        let encryptedData = try encryptionService.encrypt(model: entry)
        entity.updateEncryptedData(encryptedData)
        try await persistentStorage.save(data: entity)
    }
}

private extension EntryRepository {
    func encrypt(_ entry: Entry) throws -> EncryptedEntryEntity {
        let encryptedData = try encryptionService.encrypt(model: entry)
        return EncryptedEntryEntity(id: entry.id, encryptedData: encryptedData)
    }
}
