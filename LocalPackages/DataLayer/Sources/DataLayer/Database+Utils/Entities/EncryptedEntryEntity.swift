//
// EncryptedEntryEntity.swift
// Proton Authenticator - Created on 04/03/2025.
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
import Models
import SwiftData

@Model
public final class EncryptedEntryEntity: Equatable, Hashable, @unchecked Sendable {
    public private(set) var id: String = UUID().uuidString
    public private(set) var encryptedData = Data()
    public private(set) var keyId: String = ""
    public private(set) var order: Int = 0
    public private(set) var syncState = EntrySyncState.unsynced
    public private(set) var creationDate: TimeInterval = Date().timeIntervalSince1970
    public private(set) var modifiedTime: TimeInterval = Date().timeIntervalSince1970
    public private(set) var flags: Int = 0
    public private(set) var contentFormatVersion: Int = 0
    public private(set) var revision: Int = 0

    public init(id: String,
                encryptedData: Data,
                keyId: String,
                order: Int,
                syncState: EntrySyncState = .unsynced,
                creationDate: TimeInterval = Date().timeIntervalSince1970,
                modifiedTime: TimeInterval = Date().timeIntervalSince1970,
                flags: Int = 0,
                contentFormatVersion: Int = 0,
                revision: Int = 0) {
        self.id = id
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

    func updateEncryptedData(_ encryptedData: Data, with keyId: String) {
        self.encryptedData = encryptedData
        self.keyId = keyId
        modifiedTime = Date().timeIntervalSince1970
    }

    func updateOrder(newOrder: Int) {
        order = newOrder
        modifiedTime = Date().timeIntervalSince1970
    }

    func updateSyncState(newState: EntrySyncState) {
        syncState = newState
        modifiedTime = Date().timeIntervalSince1970
    }
}
