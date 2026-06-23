//
// EntriesViewModelSearchTests.swift
// Proton Authenticator - Created on 23/06/2026.
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
//

import Foundation
import Models
@testable import PresentationLayer
import Testing

/// Regression coverage for the search filtering logic.
///
/// Background: `executeSearch` once passed the raw, un-normalised query to the matcher, so any
/// search term containing an uppercase letter or surrounding whitespace never matched (the entries
/// are compared `lowercased()`). These tests pin the normalisation behaviour so the regression
/// cannot return.
@Suite("EntriesViewModel search filtering")
struct EntriesViewModelSearchTests {
    // MARK: - Helpers

    private func makeUiModel(id: String, name: String, issuer: String, order: Int = 0) -> EntryUiModel {
        let entry = Entry(id: id, name: name,
                          uri: "otpauth://totp/\(name)?secret=ABCDEFGH&issuer=\(issuer)",
                          period: 30, issuer: issuer, secret: "ABCDEFGH", type: .totp, note: nil)
        let code = Code(current: "123456", next: "654321", entry: entry)
        let orderedEntry = OrderedEntry(entry: entry, keyId: nil, remoteId: nil,
                                        order: order, modifiedTime: Date.now.timeIntervalSince1970,
                                        revision: 0, contentFormatVersion: 1)
        return EntryUiModel(orderedEntry: orderedEntry, code: code, issuerInfo: nil)
    }

    private var seed: [EntryUiModel] {
        [
            makeUiModel(id: "1", name: "alice@example.com", issuer: "GitHub", order: 0),
            makeUiModel(id: "2", name: "bob@example.com", issuer: "Google", order: 1),
            makeUiModel(id: "3", name: "carol@example.com", issuer: "Amazon", order: 2)
        ]
    }

    private func issuers(_ models: [EntryUiModel]) -> [String] {
        models.map(\.orderedEntry.entry.issuer)
    }

    // MARK: - Regression tests

    @Test("Uppercase query matches a lowercased issuer")
    func uppercaseQueryMatchesIssuer() async {
        let result = await seed.filtered(matching: "GIT")
        #expect(issuers(result) == ["GitHub"])
    }

    @Test("Full mixed-case issuer query matches")
    func mixedCaseQueryMatchesIssuer() async {
        let result = await seed.filtered(matching: "GitHub")
        #expect(issuers(result) == ["GitHub"])
    }

    @Test("Whitespace-padded query is trimmed before matching")
    func whitespacePaddedQueryIsTrimmed() async {
        let result = await seed.filtered(matching: "  github  ")
        #expect(issuers(result) == ["GitHub"])
    }

    @Test("Empty or whitespace-only query returns all entries")
    func emptyQueryReturnsAllEntries() async {
        let result = await seed.filtered(matching: "   ")
        #expect(issuers(result) == ["GitHub", "Google", "Amazon"])
    }

    @Test("Partial substring matches the issuer")
    func partialSubstringMatchesIssuer() async {
        let result = await seed.filtered(matching: "oog")
        #expect(issuers(result) == ["Google"])
    }

    @Test("Query matches the entry name as well as the issuer")
    func queryMatchesEntryName() async {
        let result = await seed.filtered(matching: "CAROL")
        #expect(issuers(result) == ["Amazon"])
    }
}
