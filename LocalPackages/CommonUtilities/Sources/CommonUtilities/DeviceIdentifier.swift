//
// DeviceIdentifier.swift
// Proton Authenticator - Created on 10/03/2025.
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
import Security

public enum DeviceIdentifier {
    /// Key used to store the device identifier in the keychain
    private static let keychainKey = "me.proton.uniqueDeviceIdentifier"
}

public extension DeviceIdentifier {
    /// Retrieves the device identifier from the keychain or creates a new one if it doesn't exist
    static var current: String {
        // Try to retrieve existing identifier
        if let existingIdentifier = retrieveFromKeychain() {
            return existingIdentifier
        }

        // Create new identifier if none exists
        let newIdentifier = UUID().uuidString
        storeInKeychain(identifier: newIdentifier)
        return newIdentifier
    }

    // periphery:ignore
    /// Resets the device identifier (creates a new one)
    @discardableResult
    static func reset() -> String {
        // Delete the existing identifier
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: keychainKey
        ]

        SecItemDelete(query as CFDictionary)

        // Create and store a new identifier
        let newIdentifier = UUID().uuidString
        storeInKeychain(identifier: newIdentifier)
        return newIdentifier
    }
}

private extension DeviceIdentifier {
    /// Stores the device identifier in the keychain
    @discardableResult
    static func storeInKeychain(identifier: String) -> Bool {
        guard let data = identifier.data(using: .utf8) else {
            assertionFailure("Failed to encode identifier")
            return false
        }

        // Set up keychain query
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: keychainKey,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock
        ]

        // Delete any existing item first to prevent duplicates
        SecItemDelete(query as CFDictionary)

        // Add the new item
        let status = SecItemAdd(query as CFDictionary, nil)
        let isSuccessful = status == errSecSuccess
        #if !targetEnvironment(simulator)
        assert(isSuccessful, "Failed to store identifier in keychain")
        #endif

        return isSuccessful
    }

    /// Retrieves the device identifier from the keychain
    static func retrieveFromKeychain() -> String? {
        // Set up keychain query
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: keychainKey,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let identifier = String(data: data, encoding: .utf8) else {
            return nil
        }

        return identifier
    }
}
