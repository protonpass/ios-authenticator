//
// MockedKeychainService.swift
// Proton Authenticator - Created on 27/05/2026.
// Copyright (c) 2026 Proton Technologies AG
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
import Foundation

enum MockKeychainError: Error {
    case itemNotFound
}

final class MockedKeychainService: @unchecked Sendable, KeychainServicing {
    private var storage: [String: Any] = [:]
    private(set) var setCallCount = 0
    private(set) var getCallCount = 0

    init() {}

    func get<T: Decodable & Sendable>(keyId: String, isSynced: Bool) throws -> T {
        getCallCount += 1
        guard let value = storage[keyId] as? T else {
            throw MockKeychainError.itemNotFound
        }
        return value
    }

    func set(_ item: some Encodable & Sendable, for keyId: String, shouldSync: Bool) throws {
        setCallCount += 1
        storage[keyId] = item
    }

    func delete(keyId: String, isSynced: Bool) throws {
        guard storage.removeValue(forKey: keyId) != nil else {
            throw MockKeychainError.itemNotFound
        }
    }

    func deleteAll(synchronized: Bool) throws {}

    func getAllContent() -> [[String: Any]] { [] }
}
