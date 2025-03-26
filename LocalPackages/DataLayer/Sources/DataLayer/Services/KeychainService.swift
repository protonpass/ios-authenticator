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
                                      shouldSync: Bool?) throws -> T
    func set<T: Encodable & Sendable>(_ item: T,
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
                                      shouldSync: Bool? = nil) throws -> T {
        try get(key: key, ofType: itemClassType, shouldSync: shouldSync)
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
    private let logger: LoggerProtocol?

    private let serviceSyncState: LegacyMutex<Bool> = .init(false)

    public init(service: String? = nil, accessGroup: String? = nil, logger: LoggerProtocol? = nil) {
        self.service = service
        self.accessGroup = accessGroup
        self.logger = logger
    }

    public func get<T: Decodable & Sendable>(key: String,
                                             ofType itemClassType: ItemClassType = .generic,
                                             shouldSync: Bool?) throws -> T {
        let shouldSyncData = shouldSync ?? serviceSyncState.value

        var query = createQuery(for: key, ofType: itemClassType, remoteSync: shouldSyncData)
        query[kSecMatchLimit] = kSecMatchLimitOne
        query[kSecReturnAttributes] = kCFBooleanTrue
        query[kSecReturnData] = kCFBooleanTrue

        var item: CFTypeRef?
        let result = SecItemCopyMatching(query as CFDictionary, &item)
        if result != errSecSuccess {
            throw result.toKeychainError
        }

        guard let keychainItem = item as? [CFString: Any],
              let data = keychainItem[kSecValueData] as? Data else {
            throw KeychainError.invalidData
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    public func set(_ item: some Encodable & Sendable,
                    for key: String,
                    config: KeychainQueryConfig,
                    shouldSync: Bool?) throws {
        let data = try JSONEncoder().encode(item)
        let shouldSyncData = shouldSync ?? serviceSyncState.value
        do {
            try add(with: data,
                    key: key,
                    config: config,
                    remoteSync: shouldSyncData)
        } catch KeychainError.duplicateItem {
            try update(with: data,
                       key: key,
                       config: config,
                       remoteSync: shouldSyncData)
        }
    }

    public func delete(_ key: String, ofType itemClassType: ItemClassType = .generic, shouldSync: Bool?) throws {
        let shouldSyncData = shouldSync ?? serviceSyncState.value
        let query = createQuery(for: key, ofType: itemClassType, remoteSync: shouldSyncData)
        let result = SecItemDelete(query as CFDictionary)
        if result != errSecSuccess {
            let error = result.toKeychainError
            switch error {
            case .itemNotFound:
                break
            default:
                throw error
            }
        }
    }

    public func clearAll(ofType itemClassType: ItemClassType = .generic, shouldSync: Bool?) throws {
        let shouldSyncData = shouldSync ?? serviceSyncState.value
        var query: [CFString: Any] = [kSecClass: itemClassType.rawValue]
        query[kSecAttrSynchronizable] = shouldSyncData

        if let accessGroup {
            query[kSecAttrAccessGroup] = accessGroup
        }

        let result = SecItemDelete(query as CFDictionary)
        if result != errSecSuccess {
            throw result.toKeychainError
        }
    }

    public func clear(key: String, shouldSync: Bool?) throws {
        let shouldSyncData = shouldSync ?? serviceSyncState.value
        let query = createQuery(for: key, ofType: .generic, remoteSync: shouldSyncData)

        let result = SecItemDelete(query as CFDictionary)
        if result != errSecSuccess {
            throw result.toKeychainError
        }
    }

    public func setGlobalSyncState(_ syncState: Bool) {
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
            throw result.toKeychainError
        }
    }

    func add(with data: Data,
             key: String,
             config: KeychainQueryConfig,
             remoteSync: Bool) throws {
        let query = createQuery(for: key,
                                ofType: config.itemClassType,
                                with: data,
                                access: config.access,
                                remoteSync: remoteSync,
                                attributes: config.attributes)

        let result = SecItemAdd(query as CFDictionary, nil)
        if result != errSecSuccess {
            throw result.toKeychainError
        }
    }

    func createQuery(for key: String,
                     ofType itemClassType: ItemClassType,
                     with data: Data? = nil,
                     access: KeychainAccessOptions = .default,
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

public enum KeychainError: Error, Equatable {
    case invalidData
    case itemNotFound
    case duplicateItem
    case incorrectAttributeForClass
    case unexpected(OSStatus)

    var localizedDescription: String {
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
