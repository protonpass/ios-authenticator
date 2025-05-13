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

public struct OrderedEntry: IdentifiableOrderedEntry {
    public let entry: Entry
    public let order: Int
    public let syncState: EntrySyncState
    public let creationDate: TimeInterval
    public let modifiedTime: TimeInterval
    public let flags: Int
    public let revision: Int
    public let contentFormatVersion: Int

//    public init(entry: Entry, order: Int, state: EntrySyncState = .unsynced) {
//        self.entry = entry
//        self.order = order
//        syncState = .unsynced
//    }

    public init(entry: Entry,
                order: Int,
                syncState: EntrySyncState = .unsynced,
                creationDate: TimeInterval = Date().timeIntervalSince1970,
                modifiedTime: TimeInterval = Date().timeIntervalSince1970,
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
        self.contentFormatVersion = contentFormatVersion
    }

    public var id: String { entry.id }
}

// public let entryID: String
// public let authenticatorKeyID: String
//
//
// public let content: String
// public let flags: Int
// public let createTime: Int
// public let modifyTime: Int
//

//
// public private(set) var id: String = UUID().uuidString
// public private(set) var encryptedData = Data()
// public private(set) var keyId: String = ""
// public private(set) var order: Int = 0
// public private(set) var syncState = EntrySyncState.unsynced
// public private(set) var creationDate: TimeInterval = Date().timeIntervalSince1970
// public private(set) var modifiedTime: TimeInterval = Date().timeIntervalSince1970
// public private(set) var flags: Int = 0
// public private(set) var contentFormatVersion: Int = 0
// public private(set) var revision: Int = 0
