//  
// OrderedEntryTests.swift
// Proton Authenticator - Created on 23/03/2026.
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

import Models
import Testing
import Foundation

struct OrderedEntryTests {
    private func makeUiModel(id: String, modifiedTime: TimeInterval, order: Int = 0) -> OrderedEntry {
        let entry = Entry(id: id, name: "Test-\(id)",
                          uri: "otpauth://totp/Test?secret=ABCDEFGH",
                          period: 30, issuer: "Issuer", secret: "ABCDEFGH",
                          type: .totp, note: nil)
        return OrderedEntry(entry: entry, keyId: nil, remoteId: nil,
                                        order: order, modifiedTime: modifiedTime,
                                        revision: 0, contentFormatVersion: 1)
    }

    @Test
    func `Empty ordered entry array returns empty`() {
        let result = [EntryUiModel]().deduplicatedByNewestModifiedTime()
        #expect(result.isEmpty)
    }

    @Test
    func `No duplicates ordered entries returns same array`() {
        let entries = [
            makeUiModel(id: "a", modifiedTime: 100),
            makeUiModel(id: "b", modifiedTime: 200)
        ]
        let result = entries.deduplicatedByNewestModifiedTime()
        #expect(result.count == 2)
        #expect(result.map(\.id) == ["a", "b"])
    }

    @Test
    func `Two entries with same ID keeps newest modifiedTime`() {
        let older = makeUiModel(id: "dup", modifiedTime: 100)
        let newer = makeUiModel(id: "dup", modifiedTime: 200)
        let result = [older, newer].deduplicatedByNewestModifiedTime()
        #expect(result.count == 1)
        #expect(result[0].modifiedTime == 200)
    }

    @Test
    func `Preserves order of first occurrence`() {
        let entries = [
            makeUiModel(id: "a", modifiedTime: 100),
            makeUiModel(id: "b", modifiedTime: 100),
            makeUiModel(id: "a", modifiedTime: 200)
        ]
        let result = entries.deduplicatedByNewestModifiedTime()
        #expect(result.count == 2)
        #expect(result.map(\.id) == ["a", "b"])
        #expect(result[0].modifiedTime == 200)
    }

    @Test
    func `Equal modifiedTime keeps first encountered deterministically`() {
        let first = makeUiModel(id: "dup", modifiedTime: 100, order: 0)
        let second = makeUiModel(id: "dup", modifiedTime: 100, order: 1)
        let result = [first, second].deduplicatedByNewestModifiedTime()
        #expect(result.count == 1)
        #expect(result[0].order == 0)
    }

    @Test
    func `Multiple duplicate groups handled correctly`() {
        let entries = [
            makeUiModel(id: "a", modifiedTime: 100),
            makeUiModel(id: "b", modifiedTime: 50),
            makeUiModel(id: "a", modifiedTime: 300),
            makeUiModel(id: "b", modifiedTime: 200),
            makeUiModel(id: "c", modifiedTime: 150)
        ]
        let result = entries.deduplicatedByNewestModifiedTime()
        #expect(result.count == 3)
        #expect(result.map(\.id) == ["a", "b", "c"])
        #expect(result[0].modifiedTime == 300)
        #expect(result[1].modifiedTime == 200)
        #expect(result[2].modifiedTime == 150)
    }
}
