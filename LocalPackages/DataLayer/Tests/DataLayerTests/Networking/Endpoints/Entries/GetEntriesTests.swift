//  
// GetEntriesTests.swift
// Proton Authenticator - Created on 12/05/2025.
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

@testable import DataLayer
import Testing
import Foundation

@Suite(.tags(.endpoint))
struct GetEntriesTests {
    @Test("Paginated entries decoding")
    func decodeInAppNotification() throws {
        // Given
        let string = """
{
  "Code": 1000,
  "Entries": {
    "Entries": [
      {
        "EntryID": "string",
        "AuthenticatorKeyID": "string",
        "Revision": 1,
        "ContentFormatVersion": 1,
        "Content": "abcdefg==",
        "Flags": 0,
        "CreateTime": 123456,
        "ModifyTime": 123456
      }
    ],
    "Total": 1,
    "LastID": "a1b2c3d4=="
  }
}
"""

        let remoteEncryptedEntry = RemoteEncryptedEntry(entryID: "string",
                        authenticatorKeyID: "string",
                        revision: 1,
                        contentFormatVersion: 1,
                        content: "abcdefg==",
                        flags: 0,
                        createTime: 123456,
                        modifyTime: 123456)
        let paginatedEntries = PaginatedEntries(entries: [remoteEncryptedEntry], total: 1, lastID: "a1b2c3d4==")
        let expectedResult = GetEntriesResponse(entries: paginatedEntries)

        // When
        let sut = try GetEntriesResponse.decode(from: string)

        #expect(sut == expectedResult)
    }
}

