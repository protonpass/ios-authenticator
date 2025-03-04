//
// DataState.swift
// Proton Authenticator - Created on 03/03/2025.
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

public enum DataState<T: Sendable & Equatable & Hashable>: Sendable, Equatable {
    case loading
    case loaded(T)
    case failed(Error)

    public var data: T? {
        switch self {
        case let .loaded(data):
            data
        default:
            nil
        }
    }

    public static func == (lhs: DataState<T>, rhs: DataState<T>) -> Bool {
        switch (lhs, rhs) {
        case (.failed, .failed),
             (.loading, .loading):
            true
        case let (.loaded(lhsData), .loaded(rhsData)):
            lhsData == rhsData
        default:
            false
        }
    }
}
