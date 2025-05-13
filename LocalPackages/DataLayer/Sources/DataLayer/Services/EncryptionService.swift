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
    case decrypted(Entry, EntrySyncState)
    case nonDecryptable

    public var entryAndSyncState: (Entry, EntrySyncState)? {
        switch self {
        case let .decrypted(entry, state):
            (entry, state)
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

    func symmetricEncrypt<T: Codable>(object: T) throws -> Data
    func symmetricDecrypt<T: Codable>(encryptedData: Data) throws -> T
}

// swiftlint:disable:next todo
// TODO: take into account user settings for backup sync of keychain

public final class EncryptionService: EncryptionServicing {
    public let keyId: String
    private let authenticatorCrypto: any AuthenticatorCryptoProtocol
    private let keychain: any KeychainServicing
    private let keysProvider: any KeysProvider
    private let logger: any LoggerProtocol

    public init(authenticatorCrypto: any AuthenticatorCryptoProtocol = AuthenticatorCrypto(),
                keychain: any KeychainServicing,
                keysProvider: any KeysProvider,
                deviceIdentifier: String = DeviceIdentifier.current,
                logger: any LoggerProtocol) {
        self.keychain = keychain
        self.logger = logger
        self.keysProvider = keysProvider
        keyId = "encryptionKey-\(deviceIdentifier)"
        self.authenticatorCrypto = authenticatorCrypto
    }

    private var localEncryptionKey: Data {
        get throws {
            if let key: Data = try? keychain.get(key: keyId, shouldSync: true) {
                return key
            }
            log(.info, "Generating a new local encryption key")
            let newKey = authenticatorCrypto.generateKey()
            try keychain.set(newKey, for: keyId, shouldSync: true)
            return newKey
        }
    }

    private func getEncryptionKey(for keyId: String) throws -> Data {
        log(.info, "Fetching encryption key for \(keyId)")
        let key: Data = try keychain.get(key: keyId, shouldSync: true)
        log(.info, "Retrieved key: \(String(describing: key))")
        return key
    }
}

public extension EncryptionService {
    func decrypt(entry: EncryptedEntryEntity) throws -> EntryState {
        log(.info, "Decrypting entry with id \(entry.id)")
        guard let encryptionKey = try? getEncryptionKey(for: entry.keyId) else {
            log(.warning, "Could not retrieve encryption key for \(entry.keyId)")
            return .nonDecryptable
        }
        let rustEntry = try authenticatorCrypto.decryptEntry(ciphertext: entry.encryptedData, key: encryptionKey)
        return .decrypted(rustEntry.toEntry, entry.syncState)
    }

    func decrypt(entries: [EncryptedEntryEntity]) throws -> [EntryState] {
        log(.info, "Decrypting entries")
        return try entries.map { entry in
            guard let encryptionKey = try? getEncryptionKey(for: entry.keyId) else {
                log(.warning, "Could not retrieve encryption key for \(entry.keyId)")
                return .nonDecryptable
            }
            let rustEntry = try authenticatorCrypto.decryptEntry(ciphertext: entry.encryptedData,
                                                                 key: encryptionKey)
            return .decrypted(rustEntry.toEntry, entry.syncState)
        }
    }

    func encrypt(entry: Entry) throws -> Data {
        let localKey = try localEncryptionKey
        log(.info, "Encrypting entry \(entry.name) with local encryption key")

        return try authenticatorCrypto.encryptEntry(model: entry.toRustEntry,
                                                    key: localKey)
    }

    func encrypt(entries: [Entry]) throws -> [Data] {
        let localKey = try localEncryptionKey
        log(.info, "Encrypting \(entries.count) entries with local encryption key")

        return try authenticatorCrypto.encryptManyEntries(models: entries.toRustEntries,
                                                          key: localKey)
    }

    func symmetricEncrypt(object: some Codable) throws -> Data {
        log(.info, "Encrypting entry with symmetric encryption key")
        let symmetricKey = try keysProvider.getSymmetricKey()
        let data = try JSONEncoder().encode(object)
        return try symmetricKey.encrypt(data)
    }

    func symmetricDecrypt<T: Codable>(encryptedData: Data) throws -> T {
        log(.info, "Decrypting entry with symmetric encryption key")
        let symmetricKey = try keysProvider.getSymmetricKey()
        let data = try symmetricKey.decrypt(encryptedData)
        return try JSONDecoder().decode(T.self, from: data)
    }
}

private extension EncryptionService {
    func log(_ level: LogLevel, _ message: String, function: String = #function, line: Int = #line) {
        logger.log(level, category: .data, message, function: function, line: line)
    }
}
