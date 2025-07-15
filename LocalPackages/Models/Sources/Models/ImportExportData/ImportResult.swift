//
// ImportResult.swift
// Proton Authenticator - Created on 27/02/2025.
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

public struct ImportResult: Sendable, Equatable, Hashable {
    public let entries: [Entry]
    public let errors: [ImportError]

    public init(entries: [Entry], errors: [ImportError]) {
        self.entries = entries
        self.errors = errors
    }

    public static var empty: ImportResult {
        .init(entries: [], errors: [])
    }

    public static func + (lhs: ImportResult, rhs: ImportResult) -> ImportResult {
        .init(entries: lhs.entries + rhs.entries, errors: lhs.errors + rhs.errors)
    }
}
