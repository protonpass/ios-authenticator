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

import Foundation

public protocol KeychainServicing: Sendable {
    @discardableResult
    func get<T: Decodable & Sendable>(key: String, ofType itemClassType: ItemClassType) throws -> T
    func set<T: Encodable & Sendable>(_ item: T,
                                      for key: String,
                                      ofType itemClassType: ItemClassType,
                                      with access: KeychainAccessOptions,
                                      attributes: [CFString: any Sendable]?) throws
    func delete(_ key: String, ofType itemClassType: ItemClassType) throws
    func clear(ofType itemClassType: ItemClassType) throws
}

extension KeychainServicing {
    @discardableResult
    func get<T: Decodable & Sendable>(key: String, ofType itemClassType: ItemClassType = .generic) throws -> T {
        try get(key: key, ofType: itemClassType)
    }

    func set(_ item: some Encodable & Sendable,
             for key: String,
             ofType itemClassType: ItemClassType = .generic,
             with access: KeychainAccessOptions = .default,
             attributes: [CFString: any Sendable]? = nil) throws {
        try set(item, for: key, ofType: itemClassType, with: access, attributes: attributes)
    }

    func delete(_ key: String, ofType itemClassType: ItemClassType = .generic) throws {
        try delete(key, ofType: itemClassType)
    }

    func clear(ofType itemClassType: ItemClassType = .generic) throws {
        try clear(ofType: itemClassType)
    }
}

public final class KeychainService: KeychainServicing {
    private let service: String?
    private let accessGroup: String?

    public init(service: String? = nil, accessGroup: String? = nil) {
        self.service = service
        self.accessGroup = accessGroup
    }

    @discardableResult
    public func get<T: Decodable & Sendable>(key: String,
                                             ofType itemClassType: ItemClassType = .generic) throws -> T {
        var query = createQuery(for: key, ofType: itemClassType)
        query[kSecMatchLimit] = kSecMatchLimitOne
        query[kSecReturnAttributes] = kCFBooleanTrue
        query[kSecReturnData] = kCFBooleanTrue

        var item: CFTypeRef?
        let result = SecItemCopyMatching(query as CFDictionary, &item)
        if result != errSecSuccess {
            throw result.toSimpleKeychainError
        }

        guard let keychainItem = item as? [CFString: Any],
              let data = keychainItem[kSecValueData] as? Data else {
            throw SimpleKeychainError.invalidData
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    public func set(_ item: some Encodable & Sendable,
                    for key: String,
                    ofType itemClassType: ItemClassType = .generic,
                    with access: KeychainAccessOptions = .default,
                    attributes: [CFString: any Sendable]? = nil) throws {
        let data = try JSONEncoder().encode(item)

        do {
            try add(with: data, key: key, ofType: itemClassType, with: access, attributes: attributes)
        } catch SimpleKeychainError.duplicateItem {
            try update(with: data, key: key, ofType: itemClassType, with: access, attributes: attributes)
        }
    }

    public func delete(_ key: String, ofType itemClassType: ItemClassType = .generic) throws {
        let query = createQuery(for: key, ofType: itemClassType)
        let result = SecItemDelete(query as CFDictionary)
        if result != errSecSuccess {
            let error = result.toSimpleKeychainError
            switch error {
            case .itemNotFound:
                break
            default:
                throw error
            }
        }
    }

    public func clear(ofType itemClassType: ItemClassType = .generic) throws {
        var query: [CFString: Any] = [kSecClass: itemClassType.rawValue]
        if let accessGroup {
            query[kSecAttrAccessGroup] = accessGroup
        }

        let result = SecItemDelete(query as CFDictionary)
        if result != errSecSuccess {
            throw result.toSimpleKeychainError
        }
    }
}

private extension KeychainService {
    func update(with data: Data,
                key: String,
                ofType itemClassType: ItemClassType,
                with access: KeychainAccessOptions,
                attributes: [CFString: Any]? = nil) throws {
        let query = createQuery(for: key, ofType: itemClassType, access: access, attributes: attributes)
        let updates: [CFString: Any] = [
            kSecValueData: data
        ]

        let result = SecItemUpdate(query as CFDictionary, updates as CFDictionary)
        if result != errSecSuccess {
            throw result.toSimpleKeychainError
        }
    }

    func add(with data: Data,
             key: String,
             ofType itemClassType: ItemClassType,
             with access: KeychainAccessOptions,
             attributes: [CFString: Any]? = nil) throws {
        let query = createQuery(for: key,
                                ofType: itemClassType,
                                with: data,
                                access: access,
                                attributes: attributes)

        let result = SecItemAdd(query as CFDictionary, nil)
        if result != errSecSuccess {
            throw result.toSimpleKeychainError
        }
    }

    func createQuery(for key: String,
                     ofType itemClassType: ItemClassType,
                     with data: Data? = nil,
                     access: KeychainAccessOptions = .default,
                     attributes: [CFString: Any]? = nil) -> [CFString: Any] {
        var query: [CFString: Any] = [:]
        query[kSecClass] = itemClassType.rawValue
        query[kSecAttrAccount] = key
        query[kSecAttrAccessible] = access.value
        query[kSecUseDataProtectionKeychain] = kCFBooleanTrue

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

public enum SimpleKeychainError: Error, Equatable {
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
    var toSimpleKeychainError: SimpleKeychainError {
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
