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

public struct KeychainQueryConfig {
    public let itemClassType: ItemClassType
    public let access: KeychainAccessOptions
    public let attributes: [CFString: any Sendable]?

    public init(itemClassType: ItemClassType,
                access: KeychainAccessOptions,
                attributes: [CFString: any Sendable]?) {
        self.itemClassType = itemClassType
        self.access = access
        self.attributes = attributes
    }

    public static var `default`: KeychainQueryConfig {
        KeychainQueryConfig(itemClassType: .generic, access: .default, attributes: nil)
    }
}

// swiftlint:disable discouraged_optional_boolean
public protocol KeychainServicing: Sendable {
    func get<T: Decodable & Sendable>(key: String,
                                      ofType itemClassType: ItemClassType,
                                      isSyncedKey: Bool?) throws -> T
    func set(_ item: some Encodable & Sendable,
             for key: String,
             config: KeychainQueryConfig,
             shouldSync: Bool?) throws
    func delete(_ key: String, ofType itemClassType: ItemClassType, shouldSync: Bool?) throws
    func clearAll(ofType itemClassType: ItemClassType, shouldSync: Bool?) throws
    func clear(key: String, shouldSync: Bool?) throws
    func setGlobalSyncState(_ syncState: Bool)
}

extension KeychainServicing {
    func get<T: Decodable & Sendable>(key: String,
                                      ofType itemClassType: ItemClassType = .generic,
                                      isSyncedKey: Bool? = nil) throws -> T {
        try get(key: key, ofType: itemClassType, isSyncedKey: isSyncedKey)
    }

    func set(_ item: some Encodable & Sendable,
             for key: String,
             config: KeychainQueryConfig = .default,
             shouldSync: Bool? = nil) throws {
        try set(item,
                for: key,
                config: config,
                shouldSync: shouldSync)
    }

    func delete(_ key: String, ofType itemClassType: ItemClassType = .generic, shouldSync: Bool? = nil) throws {
        try delete(key, ofType: itemClassType, shouldSync: shouldSync)
    }

    func clearAll(ofType itemClassType: ItemClassType = .generic, shouldSync: Bool? = nil) throws {
        try clearAll(ofType: itemClassType, shouldSync: shouldSync)
    }
}

public final class KeychainService: KeychainServicing {
    private let service: String?
    private let accessGroup: String?
    private let logger: LoggerProtocol

    private let serviceSyncState: any MutexProtected<Bool> = SafeMutex.create(false)

    public init(service: String? = nil, accessGroup: String? = nil, logger: LoggerProtocol) {
        self.service = service
        self.accessGroup = accessGroup
        self.logger = logger
    }

    public func get<T: Decodable & Sendable>(key: String,
                                             ofType itemClassType: ItemClassType = .generic,
                                             isSyncedKey: Bool?) throws -> T {
        log(.debug, "Getting key '\(key)' from keychain")

        let shouldSyncData = isSyncedKey ?? serviceSyncState.value

        var query = createQuery(for: key, ofType: itemClassType, remoteSync: shouldSyncData)
        query[kSecMatchLimit] = kSecMatchLimitOne
        query[kSecReturnAttributes] = kCFBooleanTrue
        query[kSecReturnData] = kCFBooleanTrue

        var item: CFTypeRef?
        let result = SecItemCopyMatching(query as CFDictionary, &item)
        if result != errSecSuccess {
            log(.error, "Failed to get key '\(key)': \(result.toKeychainError)")
            throw result.toKeychainError
        }

        guard let keychainItem = item as? [CFString: Any],
              let data = keychainItem[kSecValueData] as? Data else {
            log(.error, "Invalid keychain data for key '\(key)'")
            throw KeychainError.invalidData
        }

        let decoded = try JSONDecoder().decode(T.self, from: data)
        log(.info, "Successfully retrieved key '\(key)'")
        return decoded
    }

    public func set(_ item: some Encodable & Sendable,
                    for key: String,
                    config: KeychainQueryConfig,
                    shouldSync: Bool?) throws {
        log(.debug, "Setting key '\(key)' in keychain with config \(config)")
        let data = try JSONEncoder().encode(item)
        let shouldSyncData = shouldSync ?? serviceSyncState.value
        do {
            try add(with: data,
                    key: key,
                    config: config,
                    remoteSync: shouldSyncData)
            log(.info, "Successfully added key '\(key)' to keychain")
        } catch KeychainError.duplicateItem {
            log(.debug, "Key '\(key)' already exists. Attempting to update")
            try update(with: data,
                       key: key,
                       config: config,
                       remoteSync: shouldSyncData)
            log(.info, "Successfully updated key '\(key)' in keychain")
        }
    }

    public func delete(_ key: String, ofType itemClassType: ItemClassType = .generic, shouldSync: Bool?) throws {
        log(.debug, "Deleting key '\(key)' from keychain")
        let shouldSyncData = shouldSync ?? serviceSyncState.value
        let query = createQuery(for: key, ofType: itemClassType, remoteSync: shouldSyncData)
        let result = SecItemDelete(query as CFDictionary)
        if result != errSecSuccess {
            let error = result.toKeychainError
            switch error {
            case .itemNotFound:
                log(.debug, "Key '\(key)' not found in keychain")
            default:
                log(.error, "Failed to delete key '\(key)': \(error)")
                throw error
            }
        } else {
            log(.info, "Successfully deleted key '\(key)' from keychain")
        }
    }

    public func clearAll(ofType itemClassType: ItemClassType = .generic, shouldSync: Bool?) throws {
        log(.debug, "Clearing all keychain entries of type \(itemClassType)")
        let shouldSyncData = shouldSync ?? serviceSyncState.value
        var query: [CFString: Any] = [kSecClass: itemClassType.rawValue]
        query[kSecAttrSynchronizable] = shouldSyncData

        if let accessGroup {
            query[kSecAttrAccessGroup] = accessGroup
        }

        let result = SecItemDelete(query as CFDictionary)
        if result != errSecSuccess {
            log(.error, "Failed to clear keychain items: \(result.toKeychainError)")
            throw result.toKeychainError
        } else {
            log(.info, "Successfully cleared keychain items")
        }
    }

    public func clear(key: String, shouldSync: Bool?) throws {
        log(.debug, "Clearing key '\(key)' from keychain")
        let shouldSyncData = shouldSync ?? serviceSyncState.value
        let query = createQuery(for: key, ofType: .generic, remoteSync: shouldSyncData)

        let result = SecItemDelete(query as CFDictionary)
        if result != errSecSuccess {
            log(.error, "Failed to clear key '\(key)': \(result.toKeychainError)")
            throw result.toKeychainError
        }
        log(.info, "Successfully cleared key '\(key)' from keychain")
    }

    public func setGlobalSyncState(_ syncState: Bool) {
        log(.debug, "Setting global sync state to \(syncState)")
        serviceSyncState.modify {
            $0 = syncState
        }
    }
}

private extension KeychainService {
    func update(with data: Data,
                key: String,
                config: KeychainQueryConfig,
                remoteSync: Bool) throws {
        log(.debug, "Updating key '\(key)' with new data")
        let query = createQuery(for: key,
                                ofType: config.itemClassType,
                                access: config.access,
                                remoteSync: remoteSync,
                                attributes: config.attributes)
        let updates: [CFString: Any] = [
            kSecValueData: data
        ]

        let result = SecItemUpdate(query as CFDictionary, updates as CFDictionary)
        if result != errSecSuccess {
            log(.error, "Failed to update key '\(key)': \(result.toKeychainError)")
            throw result.toKeychainError
        }
    }

    func add(with data: Data,
             key: String,
             config: KeychainQueryConfig,
             remoteSync: Bool) throws {
        log(.debug, "Adding key '\(key)' to keychain")
        let query = createQuery(for: key,
                                ofType: config.itemClassType,
                                with: data,
                                access: config.access,
                                remoteSync: remoteSync,
                                attributes: config.attributes)

        let result = SecItemAdd(query as CFDictionary, nil)
        if result != errSecSuccess {
            log(.warning, "Failed to add key '\(key)': \(result.toKeychainError)")
            throw result.toKeychainError
        }
    }

    func createQuery(for key: String,
                     ofType itemClassType: ItemClassType,
                     with data: Data? = nil,
                     access: KeychainAccessOptions = KeychainAccessOptions.accessibleAfterFirstUnlock,
                     remoteSync: Bool,
                     attributes: [CFString: Any]? = nil) -> [CFString: Any] {
        var query: [CFString: Any] = [:]
        query[kSecClass] = itemClassType.rawValue
        query[kSecAttrAccount] = key
        query[kSecAttrAccessible] = access.value
        query[kSecUseDataProtectionKeychain] = kCFBooleanTrue
        query[kSecAttrSynchronizable] = remoteSync

        if let data {
            query[kSecValueData] = data
        }

        if let service {
            query[kSecAttrService] = service
        }

        if let accessGroup {
            query[kSecAttrAccessGroup] = accessGroup
        }

        if let attributes {
            for (key, value) in attributes {
                query[key] = value
            }
        }

        return query
    }

    func log(_ level: LogLevel, _ message: String, function: String = #function, line: Int = #line) {
        logger.log(level, category: .data, message, function: function, line: line)
    }
}

public enum ItemClassType: RawRepresentable, Sendable {
    public typealias RawValue = CFString

    case generic
    case password
    case certificate
    case cryptography
    case identity

    public init?(rawValue: CFString) {
        switch rawValue {
        case kSecClassGenericPassword:
            self = .generic
        case kSecClassInternetPassword:
            self = .password
        case kSecClassCertificate:
            self = .certificate
        case kSecClassKey:
            self = .cryptography
        case kSecClassIdentity:
            self = .identity
        default:
            return nil
        }
    }

    public var rawValue: CFString {
        switch self {
        case .generic:
            kSecClassGenericPassword
        case .password:
            kSecClassInternetPassword
        case .certificate:
            kSecClassCertificate
        case .cryptography:
            kSecClassKey
        case .identity:
            kSecClassIdentity
        }
    }
}

public enum KeychainAccessOptions: Sendable {
    case accessibleWhenUnlocked
    case accessibleWhenUnlockedThisDeviceOnly
    case accessibleAfterFirstUnlock
    case accessibleAfterFirstUnlockThisDeviceOnly
    case accessibleWhenPasscodeSetThisDeviceOnly

    public static var `default`: KeychainAccessOptions {
        .accessibleWhenUnlocked
    }

    var value: String {
        switch self {
        case .accessibleWhenUnlocked:
            kSecAttrAccessibleWhenUnlocked.toString

        case .accessibleWhenUnlockedThisDeviceOnly:
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly.toString

        case .accessibleAfterFirstUnlock:
            kSecAttrAccessibleAfterFirstUnlock.toString

        case .accessibleAfterFirstUnlockThisDeviceOnly:
            kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly.toString

        case .accessibleWhenPasscodeSetThisDeviceOnly:
            kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly.toString
        }
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

extension OSStatus {
    var toKeychainError: KeychainError {
        switch self {
        case errSecItemNotFound:
            .itemNotFound
        case errSecDataTooLarge:
            .invalidData
        case errSecDuplicateItem:
            .duplicateItem
        default:
            .unexpected(self)
        }
    }
}

extension CFString {
    var toString: String {
        self as String
    }
}

// swiftlint:enable discouraged_optional_boolean
