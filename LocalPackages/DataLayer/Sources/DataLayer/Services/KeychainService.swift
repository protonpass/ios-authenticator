//
// KeychainService.swift
// Proton Authenticator - Created on 24/03/2025.
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

// periphery:ignore:all

import CommonUtilities
import Foundation
@preconcurrency import KeychainAccess

public protocol KeychainServicing: Sendable {
    func get<T: Decodable & Sendable>(keyId: String, isSynced: Bool) throws -> T
    func set(_ item: some Encodable & Sendable, for keyId: String, shouldSync: Bool) throws
    func delete(keyId: String, isSynced: Bool) throws

    @_spi(QA)
    func deleteAll(synchronized: Bool) throws
    @_spi(QA)
    func getAllContent() -> [[String: Any]]
}

public final class KeychainService: KeychainServicing {
    private let logger: LoggerProtocol
    private let keychain: Keychain

    private let serviceSyncState: any MutexProtected<Bool> = SafeMutex.create(false)

    public init(service: String, accessGroup: String, logger: LoggerProtocol) {
        self.logger = logger
        keychain = Keychain(service: service, accessGroup: accessGroup)
    }

    public func get<T: Decodable & Sendable>(keyId: String, isSynced: Bool) throws -> T {
        guard let data = try keychain.synchronizable(isSynced).getData(keyId) else {
            throw KeychainError.itemNotFound
        }

        // Special case: Data
        if T.self == Data.self {
            // Fallback: try legacy JSON-encoded Data (base64 in JSON string)
            if let decoded = try? JSONDecoder().decode(Data.self, from: data) {
                logger.log(.info, category: .database, "Migrating legacy JSON-encoded Data for key \(keyId)")

                // 🔄 Rewrite as raw Data so future reads don't need fallback
                do {
                    try set(decoded, for: keyId, shouldSync: isSynced)
                } catch {
                    logger.log(.error,
                               category: .database,
                               "Failed to migrate legacy Data for key \(keyId): \(error)")
                }

                if let decodedReturn = decoded as? T {
                    return decodedReturn
                } else {
                    throw KeychainError.invalidData
                }
            }

            // Try interpreting as raw Data
            if let casted = data as? T {
                logger.log(.info, category: .database, "Getting raw Data for key \(keyId)")
                return casted
            } else {
                throw KeychainError.invalidData
            }
        }

        let decoded = try JSONDecoder().decode(T.self, from: data)
        return decoded
    }

    public func set(_ item: some Encodable & Sendable, for keyId: String, shouldSync: Bool) throws {
        if let data = item as? Data {
            // ✅ Always store raw Data going forward
            try keychain.synchronizable(shouldSync).set(data,
                                                        key: keyId,
                                                        ignoringAttributeSynchronizable: !shouldSync)
        } else {
            let data = try JSONEncoder().encode(item)
            try keychain.synchronizable(shouldSync).set(data,
                                                        key: keyId,
                                                        ignoringAttributeSynchronizable: !shouldSync)
        }
    }

    public func delete(keyId: String, isSynced: Bool = false) throws {
        try keychain.synchronizable(isSynced).remove(keyId)
    }

    public func deleteAll(synchronized: Bool) throws {
        try keychain.synchronizable(synchronized).removeAll()
    }

    public func getAllContent() -> [[String: Any]] {
        keychain.allItems()
    }
}

public enum KeychainError: Error, Equatable, CustomDebugStringConvertible {
    case invalidData
    case itemNotFound
    case duplicateItem
    case incorrectAttributeForClass
    case unexpected(OSStatus)

    public var debugDescription: String {
        switch self {
        case .invalidData:
            "Invalid data"
        case .itemNotFound:
            "Item not found"
        case .duplicateItem:
            "Duplicate Item"
        case .incorrectAttributeForClass:
            "Incorrect Attribute for Class"
        case let .unexpected(oSStatus):
            "Unexpected error - \(oSStatus)"
        }
    }
}
