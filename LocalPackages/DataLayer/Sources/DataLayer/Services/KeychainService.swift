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
        let decoded = try JSONDecoder().decode(T.self, from: data)
        return decoded
    }

    public func set(_ item: some Encodable & Sendable, for keyId: String, shouldSync: Bool) throws {
        let data = try JSONEncoder().encode(item)
        try keychain.synchronizable(shouldSync).set(data, key: keyId)
    }

    public func delete(keyId: String, isSynced: Bool = false) throws {
        try keychain.synchronizable(isSynced).remove(keyId)
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
