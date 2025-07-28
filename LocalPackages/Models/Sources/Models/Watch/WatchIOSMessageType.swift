//
// WatchIOSMessageType.swift
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

public struct PaginatedWatchDataCommunication: Sendable, Codable, Equatable {
    public let requestId: String
    public let orderedEntries: [OrderedEntry]
    public let currentPage: Int
    public let totalPages: Int
    public let isLastPage: Bool

    public init(requestId: String,
                orderedEntries: [OrderedEntry],
                currentPage: Int,
                totalPages: Int,
                isLastPage: Bool) {
        self.orderedEntries = orderedEntries
        self.currentPage = currentPage
        self.totalPages = totalPages
        self.requestId = requestId
        self.isLastPage = isLastPage
    }

    public static var empty: PaginatedWatchDataCommunication {
        .init(requestId: UUID().uuidString, orderedEntries: [], currentPage: 0, totalPages: 0, isLastPage: true)
    }
}

public enum WatchIOSMessageType: Codable, Equatable, Sendable {
    case syncData
    case dataContent(PaginatedWatchDataCommunication)
    case code(String)
}
