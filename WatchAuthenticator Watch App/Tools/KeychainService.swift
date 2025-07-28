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
@preconcurrency import KeychainAccess
import Security

//// swiftlint:enable discouraged_optional_boolean
protocol KeychainServicing: Sendable {
    func get<T: GenericPasswordConvertible>(key: String) throws -> T?
    func set(_ item: some GenericPasswordConvertible, key: String) throws
    // periphery:ignore
    func delete(for key: String) throws
}

struct KeychainService: KeychainServicing {
    private let keychain: Keychain

    init(keychain: Keychain = Keychain()) {
        self.keychain = keychain
    }

    /// Stores a CryptoKit key in the keychain as a generic password.
    func set(_ item: some GenericPasswordConvertible, key: String) throws {
        try keychain.set(item.dataRepresentation, key: key)
    }

    /// Reads a CryptoKit key from the keychain as a generic password.
    func get<T: GenericPasswordConvertible>(key: String) throws -> T? {
        guard let data = try keychain.getData(key) else {
            throw KeyStoreError("Could not find the data for keyid \(key)")
        }
        return try T(data: data)
    }

    /// Removes any existing key with the given account.
    func delete(for key: String) throws {
        try keychain.remove(key)
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
