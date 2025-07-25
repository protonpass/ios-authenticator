//
// EncryptionService.swift
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

import CommonUtilities
import CryptoKit
import DeviceCheck
import Foundation
import Models

public protocol EncryptionServicing: Sendable {
    var localEncryptionKeyId: String { get }

    func encrypt(entry: Entry) throws -> Data
    func decrypt(entry: EncryptedEntryEntity) throws -> OrderedEntry
    func decrypt(entries: [EncryptedEntryEntity]) throws -> [OrderedEntry]
}

final class WatchEncryptionService: EncryptionServicing {
    let localEncryptionKeyId: String
    private let keychain: any KeychainServicing

    init(keychain: any KeychainServicing) {
        self.keychain = keychain
        localEncryptionKeyId = "watchEncryptionKey"
        _ = try? encryptionKey
    }

    var encryptionKey: SymmetricKey {
        get throws {
            if let key: SymmetricKey = try? keychain.get(key: localEncryptionKeyId) {
                return key
            }
            let randomData = try Data.random()
            let newKey = SymmetricKey(data: randomData)
            try keychain.set(newKey, key: localEncryptionKeyId)
            return newKey
        }
    }
}

extension WatchEncryptionService {
    func decrypt(entry: EncryptedEntryEntity) throws -> OrderedEntry {
        let decryptedEntry: Entry = try symmetricDecrypt(encryptedData: entry.encryptedData)
        let orderedEntry = OrderedEntry(entry: decryptedEntry,
                                        keyId: entry.keyId,
                                        remoteId: entry.remoteId.nilIfEmpty,
                                        order: entry.order,
                                        syncState: entry.syncState,
                                        creationDate: entry.creationDate,
                                        modifiedTime: entry.modifiedTime,
                                        flags: entry.flags,
                                        revision: entry.revision,
                                        contentFormatVersion: entry.contentFormatVersion)
        return orderedEntry
    }

    func decrypt(entries: [EncryptedEntryEntity]) throws -> [OrderedEntry] {
        try entries.map { entry in
            try decrypt(entry: entry)
        }
    }

    func encrypt(entry: Entry) throws -> Data {
        try symmetricEncrypt(object: entry)
    }

    func symmetricEncrypt(object: some Codable) throws -> Data {
        let data = try JSONEncoder().encode(object)
        return try encryptionKey.encrypt(data)
    }

    func symmetricDecrypt<T: Codable>(encryptedData: Data) throws -> T {
        let data = try encryptionKey.decrypt(encryptedData)
        return try JSONDecoder().decode(T.self, from: data)
    }
}

/// The interface needed for SecKey conversion.
protocol GenericPasswordConvertible: CustomStringConvertible {
    /// Creates a key from a raw representation.
    init(rawRepresentation data: some ContiguousBytes) throws

    /// A raw representation of the key.
    var rawRepresentation: Data { get }
}

extension GenericPasswordConvertible {
    /// A string version of the key for visual inspection.
    /// IMPORTANT: Never log the actual key data.
    public var description: String {
        rawRepresentation.withUnsafeBytes { bytes in
            "Key representation contains \(bytes.count) bytes."
        }
    }
}

// Ensure that SymmetricKey is generic password convertible.
extension SymmetricKey: @retroactive CustomStringConvertible {}
extension SymmetricKey: GenericPasswordConvertible {
    init(rawRepresentation data: some ContiguousBytes) throws {
        self.init(data: data)
    }

    var rawRepresentation: Data {
        dataRepresentation // Contiguous bytes repackaged as a Data instance.
    }
}

extension ContiguousBytes {
    /// A Data instance created safely from the contiguous bytes without making any copies.
    var dataRepresentation: Data {
        withUnsafeBytes { bytes in
            let cfdata = CFDataCreateWithBytesNoCopy(nil, bytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                                                     bytes.count, kCFAllocatorNull)
            return ((cfdata as NSData?) as Data?) ?? Data()
        }
    }
}
