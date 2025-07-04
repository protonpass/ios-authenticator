//
// DeleteEntries.swift
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

public struct DeleteEntriesRequest: Encodable, Sendable {
    let entryIds: [String]

    public init(entryIds: [String]) {
        self.entryIds = entryIds
    }

    enum CodingKeys: String, CodingKey {
        case entryIds = "EntryIDs"
    }
}

struct DeleteEntries: Endpoint {
    typealias Body = DeleteEntriesRequest
    typealias Response = CodeOnlyResponse

    var debugDescription: String
    var path: String
    var method: HTTPMethod
    var body: DeleteEntriesRequest?

    init(request: DeleteEntriesRequest) {
        debugDescription = "Delete Proton Authenticator entries"
        path = "/authenticator/v1/entry/bulk"
        method = .delete
        body = request
    }
}
