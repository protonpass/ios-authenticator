//  
// MockKeychainService.swift
// Proton Authenticator - Created on 07/05/2025.
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
import Foundation

final class MockKeychainService: @unchecked Sendable, KeychainServicing {

    private var storage: [String: Any] = [:]
    private var globalSyncState: Bool = false
    
    // For tracking calls for verification in tests
    private(set) var callLog: [String: [Any]] = [:]
    
    init() {}
    
    // MARK: - KeychainServicing Implementation
    
    func get<T: Decodable & Sendable>(key: String, ofType itemClassType: ItemClassType, isSyncedKey: Bool?) throws -> T {
        guard let value = storage[key] as? T else {
            throw MockKeychainError.itemNotFound
        }
        return value
    }
    
    func set<T: Encodable & Sendable>(_ item: T, for key: String, config: KeychainQueryConfig, shouldSync: Bool?) throws {
        storage[key] = item
    }
    
    func delete(_ key: String, ofType itemClassType: ItemClassType, shouldSync: Bool?) throws {
        guard storage.removeValue(forKey: key) != nil else {
            throw MockKeychainError.itemNotFound
        }
    }
    
    func clearAll(ofType itemClassType: ItemClassType, shouldSync: Bool?) throws {
        storage.removeAll()
    }
    
    func clear(key: String, shouldSync: Bool?) throws {
        try delete(key, ofType: .generic, shouldSync: shouldSync)
    }
    
    func setGlobalSyncState(_ syncState: Bool) {
        globalSyncState = syncState
    }
    
    func reset() {
        storage.removeAll()
        callLog.removeAll()
        globalSyncState = false
    }
}
