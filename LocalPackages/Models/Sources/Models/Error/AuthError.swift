//
// AuthError.swift
// Proton Authenticator - Created on 05/03/2025.
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

/// Proton Authenticator errors
public enum AuthError: Error, CustomDebugStringConvertible, Equatable, Sendable {
    case importing(ImportingFailureReason)
    case imageParsing(ImageParsingFailureReason)
    case encryption(EncryptionFailureReason)
    case deeplinking(DeeplinkingFailureReason)
    case generic(GenericEntryFailureReason)
    case symmetricCrypto(SymmetricKeyCryptoFailureReasons)
    case crypto(CryptoFailureReason)
    case backup(BackUpFailureReason)
    case watchConnectivity(WatchConnectivityFailureReason)

    public var debugDescription: String {
        switch self {
        case let .importing(reason):
            reason.debugDescription
        case let .imageParsing(reason):
            reason.debugDescription
        case let .encryption(reason):
            reason.debugDescription
        case let .generic(reason):
            reason.debugDescription
        case let .deeplinking(reason):
            reason.debugDescription
        case let .symmetricCrypto(reason):
            reason.debugDescription
        case let .crypto(reason):
            reason.debugDescription
        case let .backup(reason):
            reason.debugDescription
        }
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.debugDescription == rhs.debugDescription
    }
}
