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
import DeviceCheck
import Foundation
@preconcurrency import KeychainAccess
import Models

public enum EntryState: Sendable {
    case decrypted(Entry)
    case nonDecryptable

    public var entry: Entry? {
        switch self {
        case let .decrypted(entry):
            entry
        default:
            nil
        }
    }
}

public protocol EncryptionServicing: Sendable {
    var keyId: String { get }

    func decrypt(entry: EncryptedEntryEntity) throws -> EntryState
    func decryptMany(entries: [EncryptedEntryEntity]) throws -> [EntryState]
    func encrypt(entry: Entry) throws -> Data
    func encrypt(entries: [Entry]) throws -> [Data]
}

// swiftlint:disable line_length
public final class EncryptionService: EncryptionServicing {
    public let keyId: String
    private let authenticatorCrypto: AuthenticatorCrypto
    private let keyStore: EncryptionKeyStoring
    private let logger: LoggerProtocol?
    private let deviceIdentifier: String

    public init(authenticatorCrypto: AuthenticatorCrypto = AuthenticatorCrypto(),
                keyStore: EncryptionKeyStoring,
                deviceIdentifier: String = DeviceIdentifier.current,
                logger: LoggerProtocol? = nil) {
        self.keyStore = keyStore
        self.logger = logger
        self.deviceIdentifier = deviceIdentifier
        keyId = "encryptionKey-\(deviceIdentifier)"
        self.authenticatorCrypto = authenticatorCrypto
    }

    private var localEncryptionKey: Data {
        if let key = keyStore.retrieve(keyId: keyId) {
            return key
        }
        logger?.dataLogger.notice("\(type(of: self)) - \(#function) - Generating a new local encryption key")
        let newKey = authenticatorCrypto.generateKey()
        keyStore.store(keyId: keyId, data: newKey)

        return newKey
    }

    private func getEncryptionKey(for keyId: String) -> Data? {
        logger?.dataLogger.notice("\(type(of: self)) - \(#function) - Fetching encryption key for \(keyId)")
        let key = keyStore.retrieve(keyId: keyId)
        logger?.dataLogger.notice("\(type(of: self)) - \(#function) - Retrieved key: \(String(describing: key))")
        return key
    }

    public func decrypt(entry: EncryptedEntryEntity) throws -> EntryState {
        logger?.dataLogger.notice("\(type(of: self)) - \(#function) - Decrypting entry with id \(entry.id)")
        guard let encryptionKey = getEncryptionKey(for: entry.keyId) else {
            logger?.dataLogger
                .warning("\(type(of: self)) - \(#function) - Could not retrieve encryption key for \(entry.keyId)")
            return .nonDecryptable
        }
        let entry = try authenticatorCrypto.decryptEntry(ciphertext: entry.encryptedData, key: encryptionKey)
        return .decrypted(entry.toEntry)
    }

    public func decryptMany(entries: [EncryptedEntryEntity]) throws -> [EntryState] {
        logger?.dataLogger.notice("\(type(of: self)) - \(#function) - Decrypting entries")
        return try entries.map { entry in
            guard let encryptionKey = getEncryptionKey(for: entry.keyId) else {
                logger?.dataLogger
                    .warning("\(type(of: self)) - \(#function) - Could not retrieve encryption key for \(entry.keyId)")
                return .nonDecryptable
            }
            let entry = try authenticatorCrypto.decryptEntry(ciphertext: entry.encryptedData, key: encryptionKey)
            return .decrypted(entry.toEntry)
        }
    }

    public func encrypt(entry: Entry) throws -> Data {
        let localKey = localEncryptionKey
        logger?.dataLogger
            .notice("\(type(of: self)) - \(#function) - Encrypting entry \(entry.name) with local encryption key \(localKey)")

        return try authenticatorCrypto.encryptEntry(model: entry.toAuthenticatorEntryModel,
                                                    key: localKey)
    }

    public func encrypt(entries: [Entry]) throws -> [Data] {
        let localKey = localEncryptionKey

        logger?.dataLogger
            .notice("\(type(of: self)) - \(#function) - Encrypting \(entries.count) entries with local encryption key \(localKey)")

        return try authenticatorCrypto.encryptManyEntries(models: entries.toAuthenticatorEntries,
                                                          key: localKey)
    }
}

// swiftlint:enable line_length
