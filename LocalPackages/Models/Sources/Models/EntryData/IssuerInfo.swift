//
// IssuerInfo.swift
// Proton Authenticator - Created on 27/03/2025.
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

/// Represents an issuer with its domain and optional icon
public struct AuthIssuerInfo: Sendable, Hashable, Codable {
    public let domain: String
    public let iconName: String?
    public let iconPath: String?
    public let bundleId: String?

    public init(domain: String, iconName: String? = nil, iconPath: String? = nil, bundleId: String?) {
        self.domain = domain
        self.iconName = iconName
        self.bundleId = bundleId
        self.iconPath = iconPath
    }
}
