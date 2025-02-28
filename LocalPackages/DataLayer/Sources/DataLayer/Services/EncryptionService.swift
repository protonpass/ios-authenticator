//
// EncryptionService.swift
// Proton Authenticator - Created on 11/02/2025.
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

@_exported import AuthenticatorRustCore
import CommonUtilities
import CryptoKit
import Foundation
@preconcurrency import KeychainAccess
import Models

public protocol EncryptionServicing: Sendable {
    func decrypt(entry: Data) throws -> Entry
    func decryptMany(entries: [Data]) throws -> [Entry]
    func encrypt(model: Entry) throws -> Data
    func encrypt(models: [Entry]) throws -> [Data]
}

public final class EncryptionService: EncryptionServicing {
    private let keychain: Keychain
    private let authenticatorCrypto: AuthenticatorCrypto
    private let key = "encryptionKey"

    public init(authenticatorCrypto: AuthenticatorCrypto = AuthenticatorCrypto(),
                keychain: Keychain = Keychain(service: AppConstants.service,
                                              accessGroup: AppConstants.keychainGroup)
                    .synchronizable(true)) {
        self.keychain = keychain
        self.authenticatorCrypto = authenticatorCrypto
        if keychain[data: key] == nil {
            keychain[data: key] = authenticatorCrypto.generateKey()
        }
    }

    private var encryptionKey: Data {
        get throws {
            if let key = try keychain.getData(key) {
                return key
            }
            let newKey = authenticatorCrypto.generateKey()
            keychain[data: key] = newKey
            return newKey
        }
    }

    public func decrypt(entry: Data) throws -> Entry {
        try authenticatorCrypto.decryptEntry(ciphertext: entry, key: encryptionKey).toEntry
    }

    public func decryptMany(entries: [Data]) throws -> [Entry] {
        try authenticatorCrypto.decryptManyEntries(ciphertexts: entries, key: encryptionKey).toEntries
    }

    public func encrypt(model: Entry) throws -> Data {
        try authenticatorCrypto.encryptEntry(model: model.toAuthenticatorEntryModel, key: encryptionKey)
    }

    public func encrypt(models: [Entry]) throws -> [Data] {
        try authenticatorCrypto.encryptManyEntries(models: models.toAuthenticatorEntries, key: encryptionKey)
    }
}
