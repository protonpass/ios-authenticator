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

// swiftlint:disable:next todo
// TODO: take into account user settings for backup sync of keychain

public final class EncryptionService: EncryptionServicing {
    public let keyId: String
    private let authenticatorCrypto: any AuthenticatorCryptoProtocol
    private let keyStore: KeychainServicing
    private let logger: LoggerProtocol?
    private let deviceIdentifier: String

    public init(authenticatorCrypto: any AuthenticatorCryptoProtocol = AuthenticatorCrypto(),
                keyStore: KeychainServicing,
                deviceIdentifier: String = DeviceIdentifier.current,
                logger: LoggerProtocol? = nil) {
        self.keyStore = keyStore
        self.logger = logger
        self.deviceIdentifier = deviceIdentifier
        keyId = "encryptionKey-\(deviceIdentifier)"
        self.authenticatorCrypto = authenticatorCrypto
    }

    private var localEncryptionKey: Data {
        get throws {
            if let key: Data = try? keyStore.get(key: keyId, shouldSync: true) {
                return key
            }
            logger?.log(.info, category: .data, "Generating a new local encryption key")
            let newKey = authenticatorCrypto.generateKey()
            try keyStore.set(newKey, for: keyId, shouldSync: true)
            return newKey
        }
    }

    private func getEncryptionKey(for keyId: String) throws -> Data {
        logger?.log(.info, category: .data, "Fetching encryption key for \(keyId)")
        let key: Data = try keyStore.get(key: keyId, shouldSync: true) // keyStore.retrieve(keyId: keyId)
        logger?.log(.info, category: .data, "Retrieved key: \(String(describing: key))")
        return key
    }

    public func decrypt(entry: EncryptedEntryEntity) throws -> EntryState {
        logger?.log(.info, category: .data, "Decrypting entry with id \(entry.id)")
        guard let encryptionKey = try? getEncryptionKey(for: entry.keyId) else {
            logger?.log(.warning, category: .data, "Could not retrieve encryption key for \(entry.keyId)")
            return .nonDecryptable
        }
        let entry = try authenticatorCrypto.decryptEntry(ciphertext: entry.encryptedData, key: encryptionKey)
        return .decrypted(entry.toEntry)
    }

    public func decryptMany(entries: [EncryptedEntryEntity]) throws -> [EntryState] {
        logger?.log(.info, category: .data, "Decrypting entries")
        return try entries.map { entry in
            guard let encryptionKey = try? getEncryptionKey(for: entry.keyId) else {
                logger?.log(.warning, category: .data, "Could not retrieve encryption key for \(entry.keyId)")
                return .nonDecryptable
            }
            let entry = try authenticatorCrypto.decryptEntry(ciphertext: entry.encryptedData, key: encryptionKey)
            return .decrypted(entry.toEntry)
        }
    }

    public func encrypt(entry: Entry) throws -> Data {
        let localKey = try localEncryptionKey
        logger?.log(.info, category: .data, "Encrypting entry \(entry.name) with local encryption key")

        return try authenticatorCrypto.encryptEntry(model: entry.toRustEntry,
                                                    key: localKey)
    }

    public func encrypt(entries: [Entry]) throws -> [Data] {
        let localKey = try localEncryptionKey
        logger?.log(.info, category: .data, "Encrypting \(entries.count) entries with local encryption key ")

        return try authenticatorCrypto.encryptManyEntries(models: entries.toRustEntries,
                                                          key: localKey)
    }
}
