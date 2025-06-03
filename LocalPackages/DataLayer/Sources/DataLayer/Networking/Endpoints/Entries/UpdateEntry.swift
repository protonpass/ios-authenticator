//
// UpdateEntry.swift
// Proton Authenticator - Created on 07/05/2025.
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

public struct UpdateEntryRequest: Encodable, Sendable {
    let authenticatorKeyID: String
    let content: String
    let contentFormatVersion: Int
    let lastRevision: Int

    public init(authenticatorKeyID: String, content: String, contentFormatVersion: Int, lastRevision: Int) {
        self.authenticatorKeyID = authenticatorKeyID
        self.content = content
        self.contentFormatVersion = contentFormatVersion
        self.lastRevision = lastRevision
    }

    enum CodingKeys: String, CodingKey {
        case authenticatorKeyID = "AuthenticatorKeyID"
        case content = "Content"
        case contentFormatVersion = "ContentFormatVersion"
        case lastRevision = "LastRevision"
    }
}

struct UpdateEntry: Endpoint {
    typealias Body = UpdateEntryRequest
    typealias Response = GetEntryResponse

    var debugDescription: String
    var path: String
    var method: HTTPMethod
    var body: UpdateEntryRequest?

    init(entryId: String, request: UpdateEntryRequest) {
        debugDescription = "Update a Proton Authenticator entry"
        path = "/authenticator/v1/entry/\(entryId)"
        method = .put
        body = request
    }
}
