//
// Code.swift
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

public struct Code: Sendable, Equatable, Hashable, Identifiable, Codable {
    public let current: String
    public let next: String
    public let entry: Entry
    private let precomputedHash: Int

    public init(current: String, next: String, entry: Entry) {
        self.current = current
        self.next = next
        self.entry = entry
        var hasher = Hasher()
        precomputedHash = hasher.combineAndFinalize(current, next, entry)
    }

    public static var `default`: Code {
        Code(current: "", next: "", entry: Entry.default)
    }

    public var id: Int {
        precomputedHash
    }
}
