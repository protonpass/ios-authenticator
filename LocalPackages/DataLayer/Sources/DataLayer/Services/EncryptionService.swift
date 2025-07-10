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
    case decrypted(OrderedEntry)
    case nonDecryptable

    public var entry: OrderedEntry? {
        switch self {
        case let .decrypted(entry):
            entry
        default:
            nil
        }
    }
}

public protocol EncryptionServicing: Sendable {
    var localEncryptionKeyId: String { get }
    var localEncryptionKey: Data { get throws }

    func encrypt(entry: Entry, keyId: String) throws -> Data
    // periphery:ignore
    func encrypt(entries: [Entry]) throws -> [Data]
    // periphery:ignore
    func decrypt(entry: EncryptedEntryEntity) throws -> EntryState
    func decrypt(entries: [EncryptedEntryEntity]) throws -> [EntryState]

    func symmetricEncrypt(object: some Codable) throws -> Data
    func symmetricDecrypt<T: Codable>(encryptedData: Data) throws -> T

    // MARK: - Proton BE

    func saveUserRemoteKey(keyId: String, remoteKey: Data) throws
    func contains(keyId: String) -> Bool
    func decryptRemoteData(encryptedData: RemoteEncryptedEntry) throws -> Entry?
    func getEncryptionKey(for keyId: String) throws -> Data
    func generateKey() -> Data
}

public final class EncryptionService: EncryptionServicing {
    public let localEncryptionKeyId: String
    private let authenticatorCrypto: any AuthenticatorCryptoProtocol
    private let keysProvider: any KeysProvider
    private let logger: any LoggerProtocol

    public init(authenticatorCrypto: any AuthenticatorCryptoProtocol = AuthenticatorCrypto(),
                keysProvider: any KeysProvider,
                deviceIdentifier: String = DeviceIdentifier.current,
                logger: any LoggerProtocol) {
        self.logger = logger
        self.keysProvider = keysProvider
        localEncryptionKeyId = "encryptionKey-\(deviceIdentifier)"
        self.authenticatorCrypto = authenticatorCrypto
        _ = try? localEncryptionKey
    }

    public var localEncryptionKey: Data {
        get throws {
            if let key: Data = try? keysProvider.get(keyId: localEncryptionKeyId) {
                return key
            }
            log(.info, "Generating a new local encryption key")
            let newKey = authenticatorCrypto.generateKey()
            try keysProvider.set(newKey, for: localEncryptionKeyId)
            return newKey
        }
    }

    public func getEncryptionKey(for keyId: String) throws -> Data {
        log(.info, "Fetching encryption key for \(keyId)")
        let key: Data = try keysProvider.get(keyId: keyId)
        log(.info, "Retrieved key: \(String(describing: key))")
        return key
    }

    public func generateKey() -> Data {
        log(.info, "Generating a new encryption key")
        return authenticatorCrypto.generateKey()
    }
}

public extension EncryptionService {
    // check ou cést utilisé
    func decrypt(entry: EncryptedEntryEntity) throws -> EntryState {
        log(.info, "Decrypting entry with id \(entry.id)")
        guard let encryptionKey = try? getEncryptionKey(for: entry.keyId) else {
            log(.warning, "Could not retrieve encryption key for \(entry.keyId)")
            return .nonDecryptable
        }

        let rustEntry = try authenticatorCrypto.decryptEntry(ciphertext: entry.encryptedData, key: encryptionKey)
        let orderedEntry = OrderedEntry(entry: rustEntry.toEntry,
                                        keyId: entry.keyId,
                                        remoteId: entry.remoteId.nilIfEmpty,
                                        order: entry.order,
                                        syncState: entry.syncState,
                                        creationDate: entry.creationDate,
                                        modifiedTime: entry.modifiedTime,
                                        flags: entry.flags,
                                        revision: entry.revision,
                                        contentFormatVersion: entry.contentFormatVersion)
        return .decrypted(orderedEntry)
    }

    func decrypt(entries: [EncryptedEntryEntity]) throws -> [EntryState] {
        log(.info, "Decrypting entries")
        return try entries.map { entry in
            try decrypt(entry: entry)
        }
    }

    func encrypt(entry: Entry, keyId: String) throws -> Data {
        let encryptionKey = try getEncryptionKey(for: keyId)
        log(.info, "Encrypting entry \(entry.name) with local encryption key")

        return try authenticatorCrypto.encryptEntry(model: entry.toRustEntry,
                                                    key: encryptionKey)
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

// MARK: - Proton BE

public extension EncryptionService {
    func saveUserRemoteKey(keyId: String, remoteKey: Data) throws {
        log(.info, "Saving remote proton key with id \(keyId)")
        try keysProvider.set(remoteKey, for: keyId)
    }

    func contains(keyId: String) -> Bool {
        // swiftlint:disable:next unused_optional_binding
        guard let _ = try? keysProvider.get(keyId: keyId) else {
            return false
        }

        return true
    }

    func decryptRemoteData(encryptedData: RemoteEncryptedEntry) throws -> Entry? {
        log(.info, "Decrypting proton entry with remote key id \(encryptedData.authenticatorKeyID)")

        guard let protonKey: Data = try? keysProvider.get(keyId: encryptedData.authenticatorKeyID) else {
            return nil
        }

        guard !protonKey.isEmpty else {
            log(.warning, "Proton key not found for \(encryptedData.authenticatorKeyID)")
            throw AuthError.crypto(.missingKeys)
        }

        guard let contentData = try encryptedData.content.base64Decode() else {
            log(.warning, "Could not base64 decode content data")
            throw AuthError.crypto(.failedToBase64Decode)
        }

        guard contentData.count > 12 else {
            log(.warning, "Data is too short to be a valid encrypted entry")
            throw AuthError.crypto(.corruptedContent(encryptedData.entryID))
        }

        do {
            let rustEntry = try authenticatorCrypto.decryptEntry(ciphertext: contentData, key: protonKey)
            return rustEntry.toEntry
        } catch {
            log(.error, "Rust decryption service failed to decrypt entry with remote id: \(encryptedData.entryID)")
            throw error
        }
    }
}

private extension EncryptionService {
    func log(_ level: LogLevel, _ message: String, function: String = #function, line: Int = #line) {
        logger.log(level, category: .data, message, function: function, line: line)
    }
}
