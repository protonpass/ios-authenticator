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

    func encrypt(entry: Entry) throws -> Data
    // periphery:ignore
    func encrypt(entries: [Entry]) throws -> [Data]
    // periphery:ignore
    func decrypt(entry: EncryptedEntryEntity) throws -> EntryState
    func decrypt(entries: [EncryptedEntryEntity]) throws -> [EntryState]
}

// swiftlint:disable:next todo
// TODO: take into account user settings for backup sync of keychain

public final class EncryptionService: EncryptionServicing {
    public let keyId: String
    private let authenticatorCrypto: any AuthenticatorCryptoProtocol
    private let keyStore: KeychainServicing
    private let logger: LoggerProtocol

    public init(authenticatorCrypto: any AuthenticatorCryptoProtocol = AuthenticatorCrypto(),
                keyStore: KeychainServicing,
                deviceIdentifier: String = DeviceIdentifier.current,
                logger: LoggerProtocol) {
        self.keyStore = keyStore
        self.logger = logger
        keyId = "encryptionKey-\(deviceIdentifier)"
        self.authenticatorCrypto = authenticatorCrypto
    }

    private var localEncryptionKey: Data {
        get throws {
            if let key: Data = try? keyStore.get(key: keyId, shouldSync: true) {
                return key
            }
            log(.info, "Generating a new local encryption key")
            let newKey = authenticatorCrypto.generateKey()
            try keyStore.set(newKey, for: keyId, shouldSync: true)
            return newKey
        }
    }

    private func getEncryptionKey(for keyId: String) throws -> Data {
        log(.info, "Fetching encryption key for \(keyId)")
        let key: Data = try keyStore.get(key: keyId, shouldSync: true) // keyStore.retrieve(keyId: keyId)
        log(.info, "Retrieved key: \(String(describing: key))")
        return key
    }

    // periphery:ignore
    public func decrypt(entry: EncryptedEntryEntity) throws -> EntryState {
        log(.info, "Decrypting entry with id \(entry.id)")
        guard let encryptionKey = try? getEncryptionKey(for: entry.keyId) else {
            log(.warning, "Could not retrieve encryption key for \(entry.keyId)")
            return .nonDecryptable
        }
        let entry = try authenticatorCrypto.decryptEntry(ciphertext: entry.encryptedData, key: encryptionKey)
        return .decrypted(entry.toEntry)
    }

    public func decrypt(entries: [EncryptedEntryEntity]) throws -> [EntryState] {
        log(.info, "Decrypting entries")
        return try entries.map { entry in
            guard let encryptionKey = try? getEncryptionKey(for: entry.keyId) else {
                log(.warning, "Could not retrieve encryption key for \(entry.keyId)")
                return .nonDecryptable
            }
            let entry = try authenticatorCrypto.decryptEntry(ciphertext: entry.encryptedData, key: encryptionKey)
            return .decrypted(entry.toEntry)
        }
    }

    public func encrypt(entry: Entry) throws -> Data {
        let localKey = try localEncryptionKey
        log(.info, "Encrypting entry \(entry.name) with local encryption key")

        return try authenticatorCrypto.encryptEntry(model: entry.toRustEntry,
                                                    key: localKey)
    }

    // periphery:ignore
    public func encrypt(entries: [Entry]) throws -> [Data] {
        let localKey = try localEncryptionKey
        log(.info, "Encrypting \(entries.count) entries with local encryption key ")

        return try authenticatorCrypto.encryptManyEntries(models: entries.toRustEntries,
                                                          key: localKey)
    }
}

private extension EncryptionService {
    func log(_ level: LogLevel, _ message: String) {
        logger.log(level, category: .data, message)
    }
}
