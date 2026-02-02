//
// SortOption.swift
// Proton Authenticator - Created on 3/09/2025.
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

public enum SortOption: Int, Sendable, IntegerDefaulting, CaseIterable {
    case manual
    case issuerAsc
    case issuerDesc
    case creationDateAsc
    case creationDateDesc
    case modificationDateAsc
    case modificationDateDesc

    public static var `default`: Self {
        .manual
    }

    public var isManual: Bool {
        if case .manual = self {
            true
        } else {
            false
        }
    }
}

public enum SortDirection: Equatable, Sendable {
    case ascending, descending
}
