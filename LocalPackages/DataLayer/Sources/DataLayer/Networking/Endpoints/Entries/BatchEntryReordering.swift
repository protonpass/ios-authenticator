//
// BatchEntryReordering.swift
// Proton Authenticator - Created on 21/05/2025.
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

public struct BatchOrderRequest: Encodable, Sendable {
    let startingPosition: Int
    let entries: [String]

    public init(startingPosition: Int, entries: [String]) {
        self.startingPosition = startingPosition
        self.entries = entries
    }

    enum CodingKeys: String, CodingKey {
        case startingPosition = "StartingPosition"
        case entries = "Entries"
    }
}

struct BatchEntryReordering: Endpoint {
    typealias Body = BatchOrderRequest
    typealias Response = CodeOnlyResponse

    var debugDescription: String
    var path: String
    var method: HTTPMethod
    var body: BatchOrderRequest?

    init(request: BatchOrderRequest) {
        debugDescription = "Reorder a batch of entries"
        path = "/authenticator/v1/entry/order"
        method = .put
        body = request
    }
}
