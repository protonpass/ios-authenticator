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

import Foundation

public struct Entry: Identifiable, Sendable, Hashable, Equatable, Codable {
    public let id: String
    public let name: String
    public let uri: String
    public let period: Int
    public let note: String?
    public let type: TotpType
    private let precomputedHash: Int

    public init(id: String = UUID().uuidString,
                name: String,
                uri: String,
                period: Int,
                type: TotpType,
                note: String?) {
        self.id = id
        self.name = name
        self.uri = uri
        self.period = period
        self.note = note
        self.type = type
        var hasher = Hasher()
        precomputedHash = hasher.combineAndFinalize(id, name, uri, period, note, type)
    }

    public var remainingTime: TimeInterval {
        Double(period) - Date().timeIntervalSince1970.truncatingRemainder(dividingBy: TimeInterval(period))
    }
}

// MARK: - Hashable

public extension Entry {
    func hash(into hasher: inout Hasher) {
        hasher.combine(precomputedHash)
    }
}
