//
// GetCoreEvents.swift
// Proton Authenticator - Created on 12/05/2026.
// Copyright (c) 2026 Proton Technologies AG
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
import ProtonCoreNetworking

public enum EventAction: Int, Decodable, Sendable, Equatable {
    case delete = 0
    case create = 1
    case update = 2
    case updateFlags = 3
}

public struct CoreEvent: Decodable, Sendable, Equatable {
    public let ID: String
    public let action: EventAction
}

public struct CoreEventsResponse: Decodable, Sendable, Equatable {
    public let eventID: String
    public let more: Bool
    public let refresh: Bool
    public let users: [CoreEvent]?
    public let addresses: [CoreEvent]
}

struct GetCoreEvents: Endpoint {
    typealias Body = EmptyRequest
    typealias Response = CoreEventsResponse

    var debugDescription: String
    var path: String

    init(eventId: String) {
        debugDescription = "Get core events since \(eventId)"
        path = "/core/v6/events/\(eventId)"
    }
}
