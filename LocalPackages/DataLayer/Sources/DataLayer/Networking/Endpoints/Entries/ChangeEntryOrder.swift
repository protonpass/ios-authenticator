//
// ChangeEntryOrder.swift
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

public struct NewOrderRequest: Encodable, Sendable {
    let afterID: String?

    public init(afterID: String?) {
        self.afterID = afterID
    }

    enum CodingKeys: String, CodingKey {
        case afterID = "AfterID"
    }
}

struct ChangeEntryOrder: Endpoint {
    typealias Body = NewOrderRequest
    typealias Response = CodeOnlyResponse

    var debugDescription: String
    var path: String
    var method: HTTPMethod
    var body: NewOrderRequest?

    init(entryId: String, request: NewOrderRequest) {
        debugDescription = "Move a Proton Authenticator entry"
        path = "/authenticator/v1/entry/\(entryId)/order"
        method = .put
        body = request
    }
}
