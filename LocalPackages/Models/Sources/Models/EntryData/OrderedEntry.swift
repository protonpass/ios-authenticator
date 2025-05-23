//
// OrderedEntry.swift
// Proton Authenticator - Created on 13/05/2025.
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

import Foundation

public struct OrderedEntry: IdentifiableOrderedEntry, Equatable, Hashable {
    public let entry: Entry
    public let keyId: String
    public let remoteId: String?
    public var order: Int
    public var syncState: EntrySyncState
    public let creationDate: TimeInterval
    public let modifiedTime: TimeInterval
    public let flags: Int
    public var revision: Int
    public let contentFormatVersion: Int

    public init(entry: Entry,
                keyId: String,
                remoteId: String?,
                order: Int,
                syncState: EntrySyncState = .unsynced,
                creationDate: TimeInterval = Date().timeIntervalSince1970,
                modifiedTime: TimeInterval,
                flags: Int = 0,
                revision: Int,
                contentFormatVersion: Int) {
        self.entry = entry
        self.order = order
        self.syncState = syncState
        self.creationDate = creationDate
        self.modifiedTime = modifiedTime
        self.revision = revision
        self.flags = flags
        self.keyId = keyId
        self.remoteId = remoteId
        self.contentFormatVersion = contentFormatVersion
    }

    public var id: String { entry.id }

    public func updateOrder(_ newOrder: Int) -> OrderedEntry {
        var updatedSelf = self
        updatedSelf.order = newOrder
        return updatedSelf
    }

    public func updateSyncState(_ newSyncState: EntrySyncState) -> OrderedEntry {
        var updatedSelf = self
        updatedSelf.syncState = newSyncState
        return updatedSelf
    }

    public func updateRevision(_ newRevision: Int) -> OrderedEntry {
        var updatedSelf = self
        updatedSelf.revision = newRevision
        return updatedSelf
    }

    public static func == (lhs: OrderedEntry, rhs: OrderedEntry) -> Bool {
        lhs.entry == rhs.entry &&
            lhs.remoteId == rhs.remoteId &&
            lhs.order == rhs.order &&
            lhs.syncState == rhs.syncState &&
            lhs.flags == rhs.flags &&
            lhs.revision == rhs.revision &&
            lhs.contentFormatVersion == rhs.contentFormatVersion
        // creationDate and modifiedTime are intentionally excluded
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(entry)
        hasher.combine(remoteId)
        hasher.combine(order)
        hasher.combine(syncState)
        hasher.combine(flags)
        hasher.combine(revision)
        hasher.combine(contentFormatVersion)
        // creationDate and modifiedTime are intentionally excluded
    }
}
