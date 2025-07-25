//
// KeychainService.swift
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

import CryptoKit
import Foundation
import Security

//// swiftlint:enable discouraged_optional_boolean
protocol KeychainServicing: Sendable {
    func get<T: GenericPasswordConvertible>(key: String) throws -> T?
    func set(_ item: some GenericPasswordConvertible, key: String) throws
    // periphery:ignore
    func delete(for key: String) throws
}

struct KeychainService: KeychainServicing {
    /// Stores a CryptoKit key in the keychain as a generic password.
    func set(_ item: some GenericPasswordConvertible, key: String) throws {
        // Treat the key data as a generic password.
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlocked,
            kSecUseDataProtectionKeychain: true,
            kSecValueData: item.rawRepresentation
        ] as [String: Any]

        // Add the key data.
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeyStoreError("Unable to store item: \(status.message)")
        }
    }

    /// Reads a CryptoKit key from the keychain as a generic password.
    func get<T: GenericPasswordConvertible>(key: String) throws -> T? {
        // Seek a generic password with the given account.
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecUseDataProtectionKeychain: true,
            kSecReturnData: true
        ] as [String: Any]

        // Find and cast the result as data.
        var item: CFTypeRef?
        switch SecItemCopyMatching(query as CFDictionary, &item) {
        case errSecSuccess:
            guard let data = item as? Data else { return nil }
            return try T(rawRepresentation: data) // Convert back to a key.
        case errSecItemNotFound: return nil
        case let status: throw KeyStoreError("Keychain read failed: \(status.message)")
        }
    }

    /// Removes any existing key with the given account.
    func delete(for key: String) throws {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecUseDataProtectionKeychain: true,
            kSecAttrAccount: key
        ] as [String: Any]

        switch SecItemDelete(query as CFDictionary) {
        case errSecItemNotFound, errSecSuccess: break // Okay to ignore
        case let status:
            throw KeyStoreError("Unexpected deletion error: \(status.message)")
        }
    }
}

/// An error we can throw when something goes wrong.
struct KeyStoreError: Error, CustomStringConvertible {
    var message: String

    init(_ message: String) {
        self.message = message
    }

    var description: String {
        message
    }
}

extension OSStatus {
    /// A human readable message for the status.
    var message: String {
        (SecCopyErrorMessageString(self, nil) as String?) ?? String(self)
    }
}
