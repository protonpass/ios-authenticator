//
// Entry.swift
// Proton Authenticator - Created on 11/02/2025.
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

import CoreTransferable
import Foundation

public struct Entry: Identifiable, Sendable, Hashable, Equatable, Codable {
    public var id: String
    public let name: String
    public let uri: String
    public let period: Int
    public let issuer: String
    public let secret: String
    public let note: String?
    public let type: TotpType
    private let precomputedHash: Int

    public init(id: String,
                name: String,
                uri: String,
                period: Int,
                issuer: String,
                secret: String,
                type: TotpType,
                note: String?) {
        self.id = id
        self.name = name
        self.uri = uri
        self.period = period
        self.issuer = issuer
        self.secret = secret
        self.note = note
        self.type = type
        var hasher = Hasher()
        precomputedHash = hasher.combineAndFinalize(id, name, uri, period, issuer, secret, note, type)
    }

    static var `default`: Entry {
        .init(id: "",
              name: "",
              uri: "",
              period: 30,
              issuer: "",
              secret: "",
              type: .totp,
              note: nil)
    }

    public func isDuplicate(of other: Entry) -> Bool {
        id == other.id
    }

    public var capitalLetter: String {
        issuer.first?.uppercased() ?? "-"
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, uri, period, issuer, secret, note, type
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        uri = try container.decode(String.self, forKey: .uri)
        period = try container.decode(Int.self, forKey: .period)
        issuer = try container.decode(String.self, forKey: .issuer)
        secret = try container.decode(String.self, forKey: .secret)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        type = try container.decode(TotpType.self, forKey: .type)

        // Recompute hash after decoding
        var hasher = Hasher()
        precomputedHash = hasher.combineAndFinalize(id, name, uri, period, issuer, secret, note, type)
    }
}

// MARK: - Hashable

public extension Entry {
    func hash(into hasher: inout Hasher) {
        hasher.combine(precomputedHash)
    }
}
