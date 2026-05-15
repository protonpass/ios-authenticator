//
// GetEventTests.swift
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

@testable import DataLayer
import Foundation
import Testing

@Suite(.tags(.endpoint))
struct GetCoreEventsTests {
    @Test("Decodes full event with addresses")
    func decodesFullEventWithAddresses() throws {
        let string = """
        {
          "Code": 1000,
          "EventID": "current-event-id",
          "More": true,
            "Refresh": false,
          "Addresses": [
            { "ID": "address-1", "Action": 2 },
            { "ID": "address-2", "Action": 1 }
          ]
        }
        """

        let expected = EventResponse(eventID: "current-event-id",
                                     more: true,
                                     refresh: false,
                                     users: nil,
                                     addresses: [
                                        CoreEvent(ID: "address-1", action: .update),
                                        CoreEvent(ID: "address-2", action: .create)
                                     ])

        let result = try EventResponse.decode(from: string)
        #expect(result == expected)
    }

    @Test("Decodes latest event response")
    func decodesLatestEvent() throws {
        let string = """
        {
          "Code": 1000,
          "EventID": "latest-id"
        }
        """

        let result = try GetLatestCoreEventIdResponse.decode(from: string)
        #expect(result == GetLatestCoreEventIdResponse(eventID: "latest-id"))
    }
}
