//
// TotpParams.swift
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

public struct TotpParams: Sendable, EntryParamsParameter {
    public let name: String
    public let secret: String
    public let issuer: String?
    public let period: Int?
    public let digits: Int?
    public let algorithm: TotpAlgorithm?
    public let note: String?

    public init(name: String,
                secret: String,
                issuer: String?,
                period: Int?,
                digits: Int?,
                algorithm: TotpAlgorithm?,
                note: String?) {
        self.name = name
        self.secret = secret
        self.issuer = issuer
        self.period = period
        self.digits = digits
        self.algorithm = algorithm
        self.note = note
    }
}
