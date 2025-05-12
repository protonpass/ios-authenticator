//
// SymmetricKeyCryptoFailureReasons.swift
// Proton Authenticator - Created on 30/04/2025.
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

public enum SymmetricKeyCryptoFailureReasons: CustomDebugStringConvertible, Equatable, Sendable {
    case failedToConvertUtf8ToData(String)
    case failedToBase64Decode(String)

    public var debugDescription: String {
        switch self {
        case let .failedToConvertUtf8ToData(string):
            "Failed to UTF8 convert to data \"\(string)\""
        case let .failedToBase64Decode(string):
            "Failed to base 64 decode \"\(string)\""
        }
    }
}
