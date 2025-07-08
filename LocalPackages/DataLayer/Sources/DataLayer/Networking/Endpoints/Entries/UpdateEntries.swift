//
// UpdateEntries.swift
// Proton Authenticator - Created on 02/07/2025.
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
@preconcurrency import ProtonCoreNetworking

public struct BatchUpdateEntryRequest: Encodable, Sendable {
    let entryID: String
    let authenticatorKeyID: String
    let content: String
    let contentFormatVersion: Int
    let lastRevision: Int

    public init(entryID: String,
                authenticatorKeyID: String,
                content: String,
                contentFormatVersion: Int,
                lastRevision: Int) {
        self.entryID = entryID
        self.authenticatorKeyID = authenticatorKeyID
        self.content = content
        self.contentFormatVersion = contentFormatVersion
        self.lastRevision = lastRevision
    }

    enum CodingKeys: String, CodingKey {
        case entryID = "EntryID"
        case authenticatorKeyID = "AuthenticatorKeyID"
        case content = "Content"
        case contentFormatVersion = "ContentFormatVersion"
        case lastRevision = "LastRevision"
    }
}

public struct UpdateEntriesRequest: Encodable, Sendable {
    let entries: [BatchUpdateEntryRequest]

    public init(entries: [BatchUpdateEntryRequest]) {
        self.entries = entries
    }

    enum CodingKeys: String, CodingKey {
        case entries = "Entries"
    }
}

struct UpdateEntries: Endpoint {
    typealias Body = UpdateEntriesRequest
    typealias Response = StoreEntriesResponse

    var debugDescription: String
    var path: String
    var method: HTTPMethod
    var body: UpdateEntriesRequest?

    init(request: UpdateEntriesRequest) {
        debugDescription = "Update Proton Authenticator entries"
        path = "/authenticator/v1/entry/bulk"
        method = .put
        body = request
    }
}
