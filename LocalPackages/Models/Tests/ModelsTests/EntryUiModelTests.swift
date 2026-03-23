//
// EntryUiModelTests.swift
// Proton Authenticator - Created on 05/03/2026.
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

struct EntryUiModelTests {
    private func makeUiModel(id: String, modifiedTime: TimeInterval, order: Int = 0) -> EntryUiModel {
        let entry = Entry(id: id, name: "Test-\(id)",
                          uri: "otpauth://totp/Test?secret=ABCDEFGH",
                          period: 30, issuer: "Issuer", secret: "ABCDEFGH",
                          type: .totp, note: nil)
        let code = Code(current: "123456", next: "654321", entry: entry)
        let orderedEntry = OrderedEntry(entry: entry, keyId: nil, remoteId: nil,
                                        order: order, modifiedTime: modifiedTime,
                                        revision: 0, contentFormatVersion: 1)
        return EntryUiModel(orderedEntry: orderedEntry, code: code, issuerInfo: nil)
    }

    @Test("Empty array returns empty")
    func emptyArray() {
        let result = [EntryUiModel]().deduplicatedByNewestModifiedTime()
        #expect(result.isEmpty)
    }

    @Test("No duplicates returns same array")
    func noDuplicates() {
        let entries = [
            makeUiModel(id: "a", modifiedTime: 100),
            makeUiModel(id: "b", modifiedTime: 200)
        ]
        let result = entries.deduplicatedByNewestModifiedTime()
        #expect(result.count == 2)
        #expect(result.map(\.id) == ["a", "b"])
    }

    @Test("Two entries with same ID keeps newest modifiedTime")
    func keepsNewest() {
        let older = makeUiModel(id: "dup", modifiedTime: 100)
        let newer = makeUiModel(id: "dup", modifiedTime: 200)
        let result = [older, newer].deduplicatedByNewestModifiedTime()
        #expect(result.count == 1)
        #expect(result[0].orderedEntry.modifiedTime == 200)
    }

    @Test("Preserves order of first occurrence")
    func preservesFirstOccurrenceOrder() {
        let entries = [
            makeUiModel(id: "a", modifiedTime: 100),
            makeUiModel(id: "b", modifiedTime: 100),
            makeUiModel(id: "a", modifiedTime: 200)
        ]
        let result = entries.deduplicatedByNewestModifiedTime()
        #expect(result.count == 2)
        #expect(result.map(\.id) == ["a", "b"])
        #expect(result[0].orderedEntry.modifiedTime == 200)
    }

    @Test("Equal modifiedTime keeps first encountered deterministically")
    func equalModifiedTimeKeepsFirst() {
        let first = makeUiModel(id: "dup", modifiedTime: 100, order: 0)
        let second = makeUiModel(id: "dup", modifiedTime: 100, order: 1)
        let result = [first, second].deduplicatedByNewestModifiedTime()
        #expect(result.count == 1)
        #expect(result[0].orderedEntry.order == 0)
    }

    @Test("Multiple duplicate groups handled correctly")
    func multipleDuplicateGroups() {
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
        #expect(result[0].orderedEntry.modifiedTime == 300)
        #expect(result[1].orderedEntry.modifiedTime == 200)
        #expect(result[2].orderedEntry.modifiedTime == 150)
    }
}
