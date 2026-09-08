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
    case decrypted(EncryptedEntry, OrderedEntry)
    case nonDecryptable(EncryptedEntry)

    public var entry: OrderedEntry? {
        switch self {
        case let .decrypted(_, entry):
            entry

        default:
            nil
        }
    }

    public var encryptedEntry: EncryptedEntry {
        switch self {
        case let .decrypted(entry, _):
            entry

        case let .nonDecryptable(entry):
            entry
        }
    }

    public var encryptionKeyId: String {
        switch self {
        case let .decrypted(_, entry):
            entry.keyId ?? ""

        case let .nonDecryptable(entry):
            entry.keyId
        }
    }

    public var isNonDecryptable: Bool {
        if case .nonDecryptable = self {
            true
        } else {
            false
        }
    }
}

public protocol EncryptionServicing: Sendable {
    var localEncryptionKeyId: String { get }

    func encrypt(entry: Entry, keyId: String) throws -> Data
    // periphery:ignore
    func decrypt(entry: EncryptedEntry) throws -> EntryState
    func decrypt(entries: [EncryptedEntry]) throws -> [EntryState]

    func symmetricEncrypt(object: some Encodable) throws -> Data
    func symmetricDecrypt<T: Decodable>(encryptedData: Data) throws -> T

    // MARK: - Proton BE

    func saveUserRemoteKey(keyId: String, remoteKey: Data) throws
    func contains(keyId: String) -> Bool
    func decryptRemoteData(encryptedData: RemoteEncryptedEntry) throws -> Entry?
    func getEncryptionKey(for keyId: String) throws -> Data
    func generateKey() -> Data

    @_spi(QA)
    func reset(keyId: String) throws
    @_spi(QA)
    func reset(remoteKeyId: String)
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
    }

    public func getEncryptionKey(for keyId: String) throws -> Data {
        do {
            log(.info, "Fetching encryption key for \(keyId)")
            let key = try keysProvider.get(keyId: keyId)
            log(.info, "Retrieved key for \(keyId)")
            return key
        } catch {
            if let keychainError = error as? KeychainError,
               keychainError == .itemNotFound,
               keyId == localEncryptionKeyId {
                return try generateLocalEncryptionKey()
            }
            throw error
        }
    }

    public func generateKey() -> Data {
        log(.info, "Generating a new encryption key")
        return authenticatorCrypto.generateKey()
    }
}

public extension EncryptionService {
    func decrypt(entry: EncryptedEntry) -> EntryState {
        log(.debug, "Decrypting entry with id \(entry.id), key id \(entry.keyId)")

        let encryptionKey: Data
        do {
            encryptionKey = try getEncryptionKey(for: entry.keyId)
        } catch {
            // swiftlint:disable line_length
            log(.warning,
                "Could not retrieve key id \(entry.keyId) for decrypting entry \(entry.id). \(error.localizedDescription)")
            return .nonDecryptable(entry)
            // swiftlint:enable line_length
        }

        if AppConstants.isQaBuild {
            log(.debug, "Decrypting with key hex \(entry.keyId): \(encryptionKey.hexString)")
        }

        do {
            let rustEntry = try authenticatorCrypto.decryptEntry(ciphertext: entry.encryptedData,
                                                                 key: encryptionKey)
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
            return .decrypted(entry, orderedEntry)
        } catch {
            if AppConstants.isQaBuild {
                log(.error,
                    // swiftlint:disable:next line_length
                    "Failed to decrypt entry \(entry.id) with key \(entry.keyId), hex \(encryptionKey.hexString). \(error.localizedDescription)")
            } else {
                log(.error,
                    "Failed to decrypt entry \(entry.id) with key \(entry.keyId) \(error.localizedDescription)")
            }
            return .nonDecryptable(entry)
        }
    }

    func decrypt(entries: [EncryptedEntry]) -> [EntryState] {
        log(.info, "Decrypting \(entries.count) entries")
        return entries.map { entry in
            decrypt(entry: entry)
        }
    }

    func encrypt(entry: Entry, keyId: String) throws -> Data {
        let encryptionKey = try getEncryptionKey(for: keyId)
        if AppConstants.isQaBuild {
            log(.debug, "Encrypting entry \(entry.id) with key \(keyId), hex \(encryptionKey.hexString)")
        } else {
            log(.debug, "Encrypting entry \(entry.id) with key id \(keyId)")
        }

        return try authenticatorCrypto.encryptEntry(model: entry.toRustEntry,
                                                    key: encryptionKey)
    }

    func symmetricEncrypt(object: some Encodable) throws -> Data {
        log(.info, "Encrypting \(type(of: object)) with symmetric key")
        let symmetricKey = try keysProvider.getSymmetricKey()
        let data = try JSONEncoder().encode(object)
        return try symmetricKey.encrypt(data)
    }

    func symmetricDecrypt<T: Decodable>(encryptedData: Data) throws -> T {
        log(.info, "Decrypting \(T.self) with symmetric key")
        let symmetricKey = try keysProvider.getSymmetricKey()
        let data = try symmetricKey.decrypt(encryptedData)
        return try JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - Proton BE

public extension EncryptionService {
    func saveUserRemoteKey(keyId: String, remoteKey: Data) throws {
        log(.info, "Saving remote proton key with id \(keyId)")
        if contains(keyId: keyId) {
            try keysProvider.clear(keyId: keyId)
        }
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

public extension EncryptionService {
    func reset(keyId: String) throws {
        let newKey = authenticatorCrypto.generateKey()
        try keysProvider.clear(keyId: keyId)
        try keysProvider.set(newKey, for: keyId)
    }

    func reset(remoteKeyId: String) {
        do {
            try keysProvider.clear(keyId: remoteKeyId)
        } catch {
            try? keysProvider.clear(keyId: remoteKeyId, isSynced: false)
        }
    }
}

private extension EncryptionService {
    func generateLocalEncryptionKey() throws -> Data {
        do {
            log(.info, "Generating new local encryption key with id \(localEncryptionKeyId)")
            let newKey = authenticatorCrypto.generateKey()
            try keysProvider.set(newKey, for: localEncryptionKeyId)
            return newKey
        } catch {
            log(.warning, "Failed to set the local key \(error.localizedDescription), error: \(error)")
            throw error
        }
    }

    func log(_ level: LogLevel, _ message: String, function: String = #function, line: Int = #line) {
        logger.log(level, category: .data, message, function: function, line: line)
    }
}
