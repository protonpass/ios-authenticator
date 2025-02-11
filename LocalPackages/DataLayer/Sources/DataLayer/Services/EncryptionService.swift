//
// EncryptionService.swift
// Proton Authenticator - Created on 11/02/2025.
// Copyright (c) 2025 Proton Technologies AG
//
// This file is part of Proton Pass.
//
// Proton Pass is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Proton Pass is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Proton Pass. If not, see https://www.gnu.org/licenses/.

import AuthenticatorRustCore
import CommonUtilities
import CryptoKit
import Foundation
@preconcurrency import KeychainAccess
import Models

public protocol EncryptionServicing: Sendable {
    func decrypt(ciphertext: Data) throws -> Token
    func decryptMany(ciphertexts: [Data]) throws -> [Token]
    func encrypt(model: Token) throws -> Data
    func encrypt(models: [Token]) throws -> [Data]
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

    public func decrypt(ciphertext: Data) throws -> Token {
        try authenticatorCrypto.decryptEntry(ciphertext: ciphertext, key: encryptionKey).toToken
    }

    public func decryptMany(ciphertexts: [Data]) throws -> [Token] {
        try authenticatorCrypto.decryptManyEntries(ciphertexts: ciphertexts, key: encryptionKey).toTokens
    }

    public func encrypt(model: Token) throws -> Data {
        try authenticatorCrypto.encryptEntry(model: model.toAuthenticatorEntryModel, key: encryptionKey)
    }

    public func encrypt(models: [Token]) throws -> [Data] {
        try authenticatorCrypto.encryptManyEntries(models: models.toAuthenticatorEntries, key: encryptionKey)
    }
}

// public protocol AuthenticatorCryptoProtocol : AnyObject {
//
//    func decryptEntry(ciphertext: Data, key: Data) throws -> AuthenticatorRustCore.AuthenticatorEntryModel
//
//    func decryptManyEntries(ciphertexts: [Data], key: Data) throws ->
//    [AuthenticatorRustCore.AuthenticatorEntryModel]
//
//    func encryptEntry(model: AuthenticatorRustCore.AuthenticatorEntryModel, key: Data) throws -> Data
//
//    func encryptManyEntries(models: [AuthenticatorRustCore.AuthenticatorEntryModel], key: Data) throws -> [Data]
//
//    func generateKey() -> Data
// }
