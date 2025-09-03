//
// SortOption+Extensions.swift
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

import Models

extension SortOption {
    // TODO: localize this
    var description: String {
        switch self {
        case .manual:
            "Manual"
        case .issuerAsc:
            "Issuer (A-Z)"
        case .issuerDesc:
            "Issuer (Z-A)"
        case .creationDateAsc:
            "Creation date (oldest first)"
        case .creationDateDesc:
            "Creation date (newest first)"
        case .modificationDateAsc:
            "Modification date (oldest first)"
        case .modificationDateDesc:
            "Modification date (newest first)"
        }
    }
}
