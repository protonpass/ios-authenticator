//
// EntryRepository.swift
// Proton Authenticator - Created on 25/07/2025.
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
// along with Proton Pass. If not, see https://www.gnu.org/licenses/.

import Combine
import Foundation
import Models
import SimplyPersist
import SwiftData

// swiftlint:disable line_length

public protocol EntryRepositoryProtocol: Sendable {
    @MainActor
    func getAllEntries() async throws -> [OrderedEntry]
    @MainActor
    func upsert(_ entries: [OrderedEntry]) async throws

    @MainActor
    func removeAll(_ ids: [String]) async throws
}

final class EntryRepository: EntryRepositoryProtocol {
    private let localDataManager: any LocalDataManagerProtocol
    private let encryptionService: any EncryptionServicing

    init(localDataManager: any LocalDataManagerProtocol,
         encryptionService: any EncryptionServicing) {
        self.localDataManager = localDataManager
        self.encryptionService = encryptionService
    }
}

// MARK: - CLoud / local CRUD

extension EntryRepository {
    func getAllEntries() async throws -> [OrderedEntry] {
        do {
            let encryptedEntries: [EncryptedEntryEntity] = try await localDataManager.persistentStorage
                .fetch(predicate: nil,
                       sortingDescriptor: [
                           SortDescriptor(\.order)
                       ])
            let entries = try encryptionService.decrypt(entries: encryptedEntries)
            return entries
        } catch {
            throw error
        }
    }

    func upsert(_ entries: [OrderedEntry]) async throws {
        do {
            let idsToFetch: [String] = entries.map(\.id)
            let predicate = #Predicate<EncryptedEntryEntity> { entity in
                idsToFetch.contains(entity.id)
            }

            let encryptedEntries: [EncryptedEntryEntity] = try await localDataManager.persistentStorage
                .fetch(predicate: predicate)
            let currentLocalIds = encryptedEntries.map(\.id)

            let entitiesToUpdate = entries.filter { currentLocalIds.contains($0.id) }
            try await localUpdates(encryptedEntries: encryptedEntries, entriesToUpdate: entitiesToUpdate)

            let newEntries = entries.filter { !currentLocalIds.contains($0.id) }

            let newEncryptedEntries = try newEntries.map { try encrypt($0) }

            try await localDataManager.persistentStorage.batchSave(content: newEncryptedEntries)
        } catch {
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

                let encryptedData = try encryptionService.encrypt(entry: orderedEntry.entry)
                encryptedEntry.updateEncryptedData(encryptedData,
                                                   with: keyId,
                                                   remoteModifiedTime: orderedEntry.modifiedTime)
                encryptedEntry.update(with: orderedEntry)
            }

            try await localDataManager.persistentStorage.batchSave(content: encryptedEntries)
        } catch {
            throw error
        }
    }

    func removeAll(_ ids: [String]) async throws {
        let predicate = #Predicate<EncryptedEntryEntity> { entry in
            ids.contains(entry.id)
        }
        try await localDataManager.persistentStorage.delete(EncryptedEntryEntity.self, predicate: predicate)
    }
}

// MARK: - Utils

private extension EntryRepository {
    func encrypt(_ entry: OrderedEntry) throws -> EncryptedEntryEntity {
        let encryptedData = try encryptionService.encrypt(entry: entry.entry)
        return EncryptedEntryEntity(id: entry.id,
                                    encryptedData: encryptedData,
                                    remoteId: entry.remoteId ?? "",
                                    keyId: encryptionService.localEncryptionKeyId,
                                    order: entry.order,
                                    syncState: entry.syncState,
                                    creationDate: entry.creationDate,
                                    modifiedTime: entry.modifiedTime,
                                    flags: entry.flags,
                                    contentFormatVersion: entry.contentFormatVersion,
                                    revision: entry.revision)
    }
}
