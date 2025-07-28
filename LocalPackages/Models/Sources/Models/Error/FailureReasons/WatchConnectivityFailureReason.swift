//
// WatchConnectivityFailureReason.swift
// Proton Authenticator - Created on 25/07/2025.
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

public enum WatchConnectivityFailureReason: CustomDebugStringConvertible, Equatable, Sendable {
    case companionNotReachable
    case messageDecodingFailed(String)
    case sessionActivationFailed(String)
    case timeout
    case sessionNotActivated
    case notPaired

    public var debugDescription: String {
        switch self {
        case .companionNotReachable:
            "Could not reach the companion app"
        case let .messageDecodingFailed(error):
            "Failed to decode received message: \(error)"
        case let .sessionActivationFailed(error):
            "Failed to activate session: \(error)"
        case .timeout:
            "Connection to the companion app timed out"
        case .sessionNotActivated:
            "Session not activated yet"
        case .notPaired:
            "Not paired with the companion app"
        }
    }
}
