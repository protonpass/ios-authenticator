//
// GetKeys.swift
// Proton Authenticator - Created on 06/05/2025.
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

struct RemoteEncryptedKey: Decodable, Equatable, Sendable {
    // An encrypted ID
    let keyID: String

    // Base64 representation of the authenticator key encrypted with the user key
    let key: String
}

struct PaginatedKeys: Decodable, Equatable, Sendable {
    let keys: [RemoteEncryptedKey]
}

struct GetKeysResponse: Decodable, Equatable, Sendable {
    let keys: PaginatedKeys
}

struct GetKeys: Endpoint {
    typealias Body = EmptyRequest
    typealias Response = GetKeysResponse

    var debugDescription: String
    var path: String

    init() {
        debugDescription = "Get the proton authenticator Keys"
        path = "/authenticator/v1/key"
    }
}
