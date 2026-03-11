//
// DuplicateEntryGroup.swift
// Proton Authenticator - Created on 25/02/2026.
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
import Models

/// A single copy of a duplicated entry, identified by its `entryId` + `modifiedTime` + `creationDate` triple.
public struct DuplicateEntryInfo: Sendable, Identifiable, Equatable {
    public var id: String {
        "\(entryId)_\(modifiedTime)_\(creationDate)"
    }

    public let entryId: String
    public let modifiedTime: TimeInterval
    public let creationDate: TimeInterval
    public let syncState: EntrySyncState
    public let hasRemoteId: Bool
    public let revision: Int
    public let displayName: String
    public let issuer: String
    /// `true` for the copy currently used by the app (most recently modified).
    public let isCurrentlyActive: Bool
}

/// A group of entries that share the same logical `entryId` but exist as multiple
/// database rows — i.e. duplicates detected via `modifiedTime` ordering.
public struct DuplicateEntryGroup: Sendable, Identifiable, Equatable {
    public var id: String {
        entryId
    }

    public let entryId: String
    public let displayName: String
    public let issuer: String
    /// All copies sorted by `modifiedTime` descending (index 0 = currently active).
    public let entries: [DuplicateEntryInfo]
}
