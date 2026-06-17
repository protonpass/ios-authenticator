//
// EncryptedEntry.swift
// Proton Authenticator - Created on 11/06/2026.
// Copyright (c) 2026 Proton Technologies AG
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

import Foundation

/// An immutable, `Sendable` value snapshot of an ``EncryptedEntryEntity``'s stored fields.
///
/// `EncryptedEntryEntity` is a SwiftData `@Model` whose live instances are bound to the
/// `ModelContext` they were fetched from. Reading their properties after that context is reset or
/// deallocated (e.g. when the persistent store is recreated on an iCloud-sync toggle) traps with a
/// `_DestroyedBackingData` fatal error. Decrypting and passing data up the stack must therefore
/// operate on a detached snapshot rather than the live model, so values can safely outlive — and
/// cross actor boundaries away from — their owning context.
public struct EncryptedEntry: Sendable, Equatable, Hashable {
    public let id: String
    public let remoteId: String
    public let encryptedData: Data
    public let keyId: String
    public let order: Int
    public let syncState: EntrySyncState
    public let creationDate: TimeInterval
    public let modifiedTime: TimeInterval
    public let flags: Int
    public let contentFormatVersion: Int
    public let revision: Int

    public init(id: String,
                remoteId: String,
                encryptedData: Data,
                keyId: String,
                order: Int,
                syncState: EntrySyncState,
                creationDate: TimeInterval,
                modifiedTime: TimeInterval,
                flags: Int,
                contentFormatVersion: Int,
                revision: Int) {
        self.id = id
        self.remoteId = remoteId
        self.encryptedData = encryptedData
        self.keyId = keyId
        self.order = order
        self.syncState = syncState
        self.creationDate = creationDate
        self.modifiedTime = modifiedTime
        self.flags = flags
        self.contentFormatVersion = contentFormatVersion
        self.revision = revision
    }
}

public extension EncryptedEntry {
    init(from entity: EncryptedEntryEntity) {
        self.init(id: entity.id,
                  remoteId: entity.remoteId,
                  encryptedData: entity.encryptedData,
                  keyId: entity.keyId,
                  order: entity.order,
                  syncState: entity.syncState,
                  creationDate: entity.creationDate,
                  modifiedTime: entity.modifiedTime,
                  flags: entity.flags,
                  contentFormatVersion: entity.contentFormatVersion,
                  revision: entity.revision)
    }
}
