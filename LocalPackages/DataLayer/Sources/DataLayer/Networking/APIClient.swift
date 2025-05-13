//
// APIClient.swift
// Proton Authenticator - Created on 06/05/2025.
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

import Foundation
import Models

// MARK: - Keys

public protocol RemoteKeysDataSource: Sendable {
    func getKeys() async throws -> [RemoteEncryptedKey]
    func storeKey(encryptedKey: String) async throws -> RemoteEncryptedKey
}

// MARK: - Entries

public protocol RemoteEntriesDataSource: Sendable {
    func getEntries(lastId: String?) async throws -> [RemoteEncryptedEntry]
    func storeEntry(request: StoreEntryRequest) async throws -> RemoteEncryptedEntry
    func storeEntries(request: StoreEntriesRequest) async throws -> [RemoteEncryptedEntry]
    func update(entryId: String, request: UpdateEntryRequest) async throws -> RemoteEncryptedEntry
    func delete(entryId: String) async throws
    func changeOrder(entryId: String, request: NewOrderRequest) async throws
}

public typealias APIClientProtocol = RemoteEntriesDataSource & RemoteKeysDataSource

public final class APIClient: APIClientProtocol {
    private let manager: any APIManagerProtocol
    private let logger: any LoggerProtocol

    public init(manager: any APIManagerProtocol,
                logger: any LoggerProtocol) {
        self.logger = logger
        self.manager = manager
    }
}

private extension APIClient {
    func exec<E: Endpoint>(endpoint: E) async throws -> E.Response {
        log(.debug, "Executing endpoint: \(E.self)")
        do {
            let response = try await manager.apiService.exec(endpoint: endpoint)
            log(.info, "Successfully received response: \(response) for endpoint: \(E.self)")
            return response
        } catch {
            log(.error, "Failed to execute endpoint: \(E.self), error: \(error.localizedDescription)")
            throw error
        }
    }

    func log(_ level: LogLevel, _ message: String, function: String = #function, line: Int = #line) {
        logger.log(level, category: .data, message, function: function, line: line)
    }
}

public extension APIClient {
    func getKeys() async throws -> [RemoteEncryptedKey] {
        log(.debug, "Fetching keys")
        let endpoint = GetKeys()
        let response = try await exec(endpoint: endpoint)
        return response.keys.keys
    }

    func storeKey(encryptedKey: String) async throws -> RemoteEncryptedKey {
        log(.debug, "Storing encrypted key")
        let endpoint = StoreKey(encryptedKey: encryptedKey)
        let response = try await exec(endpoint: endpoint)
        return response.key
    }
}

public extension RemoteEntriesDataSource {
    func getEntries(lastId: String? = nil) async throws -> [RemoteEncryptedEntry] {
        try await getEntries(lastId: lastId)
    }
}

public extension APIClient {
    func getEntries(lastId: String? = nil) async throws -> [RemoteEncryptedEntry] {
        log(.debug, "Fetching entries with lastId: \(lastId ?? "nil")")
        let endpoint = GetEntries(lastId: lastId)
        let response = try await exec(endpoint: endpoint)
        return response.entries.entries
    }

    func storeEntry(request: StoreEntryRequest) async throws -> RemoteEncryptedEntry {
        log(.debug, "Storing single entry")
        let endpoint = StoreEntry(request: request)
        let response = try await exec(endpoint: endpoint)
        return response.entry
    }

    func storeEntries(request: StoreEntriesRequest) async throws -> [RemoteEncryptedEntry] {
        log(.debug, "Storing multiple entries")
        let endpoint = StoreEntries(request: request)
        let response = try await exec(endpoint: endpoint)
        return response.entries.entries
    }

    func update(entryId: String, request: UpdateEntryRequest) async throws -> RemoteEncryptedEntry {
        log(.debug, "Updating entry with ID: \(entryId)")
        let endpoint = UpdateEntry(entryId: entryId, request: request)
        let response = try await exec(endpoint: endpoint)
        return response.entry
    }

    func delete(entryId: String) async throws {
        log(.debug, "Deleting entry with ID: \(entryId)")
        let endpoint = DeleteEntry(entryId: entryId)
        _ = try await exec(endpoint: endpoint)
    }

    func changeOrder(entryId: String, request: NewOrderRequest) async throws {
        log(.debug, "Changing order for entry ID: \(entryId), placed after entry ID: \(request.afterID)")
        let endpoint = ChangeEntryOrder(entryId: entryId, request: request)
        _ = try await exec(endpoint: endpoint)
    }
}
