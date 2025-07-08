//  
// MockApiClient.swift
// Proton Authenticator - Created on 13/05/2025.
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

import DataLayer
import Models

extension RemoteEncryptedKey {
    static var mock: RemoteEncryptedKey {
        .init(keyID: "id", userKeyID: "userKeyId", key: "default")
    }
}

extension PaginatedEntries {
    static var mock: PaginatedEntries {
        .init(entries: [], total: 0, lastID: nil)
    }
}

extension RemoteEncryptedEntry {
    static var mock: RemoteEncryptedEntry {
        .init(entryID: "id",
                            authenticatorKeyID: "keyID",
                            revision: 1,
                            contentFormatVersion: 1,
                            content: "data",
                            flags: 0,
                            createTime: 123456,
                            modifyTime: 123456)
    }
}

public final class MockAPIClient: @unchecked Sendable, APIClientProtocol {
    // MARK: - Stubs
    
    public var getKeysResult: Result<[RemoteEncryptedKey], Error> = .success([])
    public var storeKeyResult: Result<RemoteEncryptedKey, Error> = .success(RemoteEncryptedKey.mock)

    public var getEntriesResult: Result<PaginatedEntries, Error> = .success(PaginatedEntries.mock)
    public var storeEntryResult: Result<RemoteEncryptedEntry, Error> = .success(RemoteEncryptedEntry.mock)
    public var storeEntriesResult: Result<[RemoteEncryptedEntry], Error> = .success([])
    public var updateResult: Result<RemoteEncryptedEntry, Error> = .success(RemoteEncryptedEntry.mock)
    public var deleteShouldSucceed: Bool = true
    public var changeOrderShouldSucceed: Bool = true
    public var batchOrderingSucceed: Bool = true


    // MARK: - Tracking
    
    public private(set) var calledMethods: [String] = []

    // MARK: - RemoteKeysDataSource
    
    public func getKeys() async throws -> [RemoteEncryptedKey] {
        calledMethods.append(#function)
        return try getKeysResult.get()
    }

    public func storeKey(encryptedKey: String) async throws -> RemoteEncryptedKey {
        calledMethods.append(#function)
        return try storeKeyResult.get()
    }

    // MARK: - RemoteEntriesDataSource

    public func getEntries(lastId: String? = nil) async throws -> PaginatedEntries {
        calledMethods.append(#function)
        return try getEntriesResult.get()
    }

    public func storeEntry(request: StoreEntryRequest) async throws -> RemoteEncryptedEntry {
        calledMethods.append(#function)
        return try storeEntryResult.get()
    }

    public func storeEntries(request: StoreEntriesRequest) async throws -> [RemoteEncryptedEntry] {
        calledMethods.append(#function)
        return try storeEntriesResult.get()
    }

    public func update(entryId: String, request: UpdateEntryRequest) async throws -> RemoteEncryptedEntry {
        calledMethods.append(#function)
        return try updateResult.get()
    }

    public func delete(entryId: String) async throws {
        calledMethods.append(#function)
        if !deleteShouldSucceed {
            throw MockError.stub
        }
    }

    public func changeOrder(entryId: String, request: NewOrderRequest) async throws {
        calledMethods.append(#function)
        if !changeOrderShouldSucceed {
            throw MockError.stub
        }
    }
    
    public func batchOrdering(request: BatchOrderRequest) async throws {
        calledMethods.append(#function)
        if !batchOrderingSucceed {
            throw MockError.stub
        }
    }
    
    public func updates(request: UpdateEntriesRequest) async throws -> [RemoteEncryptedEntry] {
        []
    }
    
    public func delete(entryIds: [String]) async throws {
        
    }
    
    // MARK: - Helpers

    public enum MockError: Error {
        case stub
    }

    public init() {}
}
