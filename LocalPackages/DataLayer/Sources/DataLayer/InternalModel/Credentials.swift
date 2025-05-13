//
// Credentials.swift
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

@preconcurrency import ProtonCoreNetworking

// MARK: - Keychain codable wrappers for credential elements & extensions

struct Credentials: Hashable, Sendable, Codable {
    let credential: Credential
    let authCredential: AuthCredential
}

extension Credential: Codable, @retroactive Hashable {
    private enum CodingKeys: String, CodingKey {
        case UID
        case accessToken
        case refreshToken
        case userName
        case userID
        case scopes
        case mailboxPassword
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(UID)
        hasher.combine(accessToken)
        hasher.combine(refreshToken)
        hasher.combine(userName)
        hasher.combine(userID)
        hasher.combine(scopes)
        hasher.combine(mailboxPassword)
    }

    public init(from decoder: any Decoder) throws {
        self.init(UID: "",
                  accessToken: "",
                  refreshToken: "",
                  userName: "",
                  userID: "",
                  scopes: [],
                  mailboxPassword: "")
        let values = try decoder.container(keyedBy: CodingKeys.self)
        UID = try values.decode(String.self, forKey: .UID)
        accessToken = try values.decode(String.self, forKey: .accessToken)
        refreshToken = try values.decode(String.self, forKey: .refreshToken)
        userName = try values.decode(String.self, forKey: .userName)
        userID = try values.decode(String.self, forKey: .userID)
        scopes = try values.decode([String].self, forKey: .scopes)
        mailboxPassword = try values.decode(String.self, forKey: .mailboxPassword)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(UID, forKey: .UID)
        try container.encode(accessToken, forKey: .accessToken)
        try container.encode(refreshToken, forKey: .refreshToken)
        try container.encode(userName, forKey: .userName)
        try container.encode(userID, forKey: .userID)
        try container.encode(scopes, forKey: .scopes)
        try container.encode(mailboxPassword, forKey: .mailboxPassword)
    }
}
