//
// OrderedEntryHashTests.swift
// Proton Authenticator - Created on 28/05/2026.
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
import Models
import Testing

@Suite(.tags(.service))
struct OrderedEntryHashTests {
    // MARK: - Helpers

    private func makeEntry(id: String = "id",
                           name: String = "Name",
                           uri: String = "otpauth://totp/Name?secret=ABCDEFGH&issuer=Iss",
                           period: Int = 30,
                           issuer: String = "Iss",
                           secret: String = "ABCDEFGH",
                           type: TotpType = .totp,
                           note: String? = nil) -> Entry {
        Entry(id: id,
              name: name,
              uri: uri,
              period: period,
              issuer: issuer,
              secret: secret,
              type: type,
              note: note)
    }

    private func makeOrderedEntry(id: String = "id",
                                  name: String = "Name",
                                  uri: String = "otpauth://totp/Name?secret=ABCDEFGH&issuer=Iss",
                                  period: Int = 30,
                                  issuer: String = "Iss",
                                  secret: String = "ABCDEFGH",
                                  type: TotpType = .totp,
                                  note: String? = nil,
                                  keyId: String? = "key",
                                  remoteId: String? = "remote",
                                  order: Int = 0,
                                  syncState: EntrySyncState = .unsynced,
                                  creationDate: TimeInterval = 100,
                                  modifiedTime: TimeInterval = 100,
                                  flags: Int = 0,
                                  revision: Int = 0,
                                  contentFormatVersion: Int = 1) -> OrderedEntry {
        OrderedEntry(entry: makeEntry(id: id,
                                      name: name,
                                      uri: uri,
                                      period: period,
                                      issuer: issuer,
                                      secret: secret,
                                      type: type,
                                      note: note),
                     keyId: keyId,
                     remoteId: remoteId,
                     order: order,
                     syncState: syncState,
                     creationDate: creationDate,
                     modifiedTime: modifiedTime,
                     flags: flags,
                     revision: revision,
                     contentFormatVersion: contentFormatVersion)
    }

    // MARK: - Format and base cases

    @Test("Empty array returns empty string")
    func emptyArrayReturnsEmptyString() {
        let entries: [OrderedEntry] = []
        #expect(entries.computeHashValue() == "")
    }

    @Test("Single entry returns 64 lowercase hex chars")
    func singleEntryReturns64LowercaseHexChars() {
        let hash = [makeOrderedEntry()].computeHashValue()
        #expect(hash.count == 64)
        #expect(hash.allSatisfy { $0.isHexDigit && (!$0.isLetter || $0.isLowercase) })
    }

    @Test("Same input returns same hash on repeated calls")
    func sameInputReturnsSameHashOnRepeatedCalls() {
        let entries = [makeOrderedEntry()]
        #expect(entries.computeHashValue() == entries.computeHashValue())
    }

    @Test("Same input across freshly built arrays returns same hash")
    func sameInputAcrossFreshlyBuiltArraysReturnsSameHash() {
        let first = [makeOrderedEntry()].computeHashValue()
        let second = [makeOrderedEntry()].computeHashValue()
        #expect(first == second)
    }

    // MARK: - Order independence

    @Test("Hash is independent of array order")
    func hashIsIndependentOfArrayOrder() {
        let a = makeOrderedEntry(id: "a")
        let b = makeOrderedEntry(id: "b")
        let c = makeOrderedEntry(id: "c")
        #expect([a, b, c].computeHashValue() == [c, a, b].computeHashValue())
        #expect([a, b, c].computeHashValue() == [b, c, a].computeHashValue())
    }

    // MARK: - Sensitivity to included fields

    @Test("Changing entry.id changes the hash")
    func changingEntryIdChangesHash() {
        let lhs = [makeOrderedEntry(id: "id-1")].computeHashValue()
        let rhs = [makeOrderedEntry(id: "id-2")].computeHashValue()
        #expect(lhs != rhs)
    }

    @Test("Changing entry.name changes the hash")
    func changingEntryNameChangesHash() {
        let lhs = [makeOrderedEntry(name: "First")].computeHashValue()
        let rhs = [makeOrderedEntry(name: "Second")].computeHashValue()
        #expect(lhs != rhs)
    }

    @Test("Changing entry.uri changes the hash")
    func changingEntryUriChangesHash() {
        let lhs = [makeOrderedEntry(uri: "otpauth://totp/A")].computeHashValue()
        let rhs = [makeOrderedEntry(uri: "otpauth://totp/B")].computeHashValue()
        #expect(lhs != rhs)
    }

    @Test("Changing entry.issuer changes the hash")
    func changingEntryIssuerChangesHash() {
        let lhs = [makeOrderedEntry(issuer: "IssuerA")].computeHashValue()
        let rhs = [makeOrderedEntry(issuer: "IssuerB")].computeHashValue()
        #expect(lhs != rhs)
    }

    @Test("Changing entry.secret changes the hash")
    func changingEntrySecretChangesHash() {
        let lhs = [makeOrderedEntry(secret: "ABCDEFGH")].computeHashValue()
        let rhs = [makeOrderedEntry(secret: "HGFEDCBA")].computeHashValue()
        #expect(lhs != rhs)
    }

    @Test("Changing entry.note from nil to value changes the hash")
    func changingEntryNoteFromNilToValueChangesHash() {
        let lhs = [makeOrderedEntry(note: nil)].computeHashValue()
        let rhs = [makeOrderedEntry(note: "x")].computeHashValue()
        #expect(lhs != rhs)
    }

    @Test("entry.note nil and empty string produce the same hash")
    func entryNoteNilAndEmptyStringProduceSameHash() {
        let nilHash = [makeOrderedEntry(note: nil)].computeHashValue()
        let emptyHash = [makeOrderedEntry(note: "")].computeHashValue()
        #expect(nilHash == emptyHash)
    }

    @Test("Changing entry.type changes the hash")
    func changingEntryTypeChangesHash() {
        let lhs = [makeOrderedEntry(type: .totp)].computeHashValue()
        let rhs = [makeOrderedEntry(type: .steam)].computeHashValue()
        #expect(lhs != rhs)
    }

    @Test("Changing entry.period changes the hash")
    func changingEntryPeriodChangesHash() {
        let lhs = [makeOrderedEntry(period: 30)].computeHashValue()
        let rhs = [makeOrderedEntry(period: 60)].computeHashValue()
        #expect(lhs != rhs)
    }

    @Test("Changing revision changes the hash")
    func changingRevisionChangesHash() {
        let lhs = [makeOrderedEntry(revision: 0)].computeHashValue()
        let rhs = [makeOrderedEntry(revision: 1)].computeHashValue()
        #expect(lhs != rhs)
    }

    @Test("Changing flags changes the hash")
    func changingFlagsChangesHash() {
        let lhs = [makeOrderedEntry(flags: 0)].computeHashValue()
        let rhs = [makeOrderedEntry(flags: 1)].computeHashValue()
        #expect(lhs != rhs)
    }

    @Test("Changing contentFormatVersion changes the hash")
    func changingContentFormatVersionChangesHash() {
        let lhs = [makeOrderedEntry(contentFormatVersion: 1)].computeHashValue()
        let rhs = [makeOrderedEntry(contentFormatVersion: 2)].computeHashValue()
        #expect(lhs != rhs)
    }

    @Test("Changing syncState changes the hash")
    func changingSyncStateChangesHash() {
        let lhs = [makeOrderedEntry(syncState: .unsynced)].computeHashValue()
        let rhs = [makeOrderedEntry(syncState: .synced)].computeHashValue()
        #expect(lhs != rhs)
    }

    @Test("Changing remoteId from nil to value changes the hash")
    func changingRemoteIdFromNilToValueChangesHash() {
        let lhs = [makeOrderedEntry(remoteId: nil)].computeHashValue()
        let rhs = [makeOrderedEntry(remoteId: "r")].computeHashValue()
        #expect(lhs != rhs)
    }

    @Test("remoteId nil and empty string produce the same hash")
    func remoteIdNilAndEmptyStringProduceSameHash() {
        let nilHash = [makeOrderedEntry(remoteId: nil)].computeHashValue()
        let emptyHash = [makeOrderedEntry(remoteId: "")].computeHashValue()
        #expect(nilHash == emptyHash)
    }

    @Test("Changing keyId from nil to value changes the hash")
    func changingKeyIdFromNilToValueChangesHash() {
        let lhs = [makeOrderedEntry(keyId: nil)].computeHashValue()
        let rhs = [makeOrderedEntry(keyId: "k")].computeHashValue()
        #expect(lhs != rhs)
    }

    @Test("keyId nil and empty string produce the same hash")
    func keyIdNilAndEmptyStringProduceSameHash() {
        let nilHash = [makeOrderedEntry(keyId: nil)].computeHashValue()
        let emptyHash = [makeOrderedEntry(keyId: "")].computeHashValue()
        #expect(nilHash == emptyHash)
    }

    // MARK: - Insensitivity to excluded fields

    @Test("Changing order does not change the hash")
    func changingOrderDoesNotChangeHash() {
        let lhs = [makeOrderedEntry(order: 0)].computeHashValue()
        let rhs = [makeOrderedEntry(order: 99)].computeHashValue()
        #expect(lhs == rhs)
    }

    @Test("Changing modifiedTime does not change the hash")
    func changingModifiedTimeDoesNotChangeHash() {
        let lhs = [makeOrderedEntry(modifiedTime: 100)].computeHashValue()
        let rhs = [makeOrderedEntry(modifiedTime: 9_999_999)].computeHashValue()
        #expect(lhs == rhs)
    }

    @Test("Changing creationDate does not change the hash")
    func changingCreationDateDoesNotChangeHash() {
        let lhs = [makeOrderedEntry(creationDate: 100)].computeHashValue()
        let rhs = [makeOrderedEntry(creationDate: 9_999_999)].computeHashValue()
        #expect(lhs == rhs)
    }

    // MARK: - Length-prefix boundary safety

    @Test("Adjacent string fields cannot be confused by splitting bytes differently")
    func adjacentStringFieldsCannotBeConfused() {
        let lhs = [makeOrderedEntry(issuer: "ab", secret: "c")].computeHashValue()
        let rhs = [makeOrderedEntry(issuer: "a", secret: "bc")].computeHashValue()
        #expect(lhs != rhs)
    }

    // MARK: - Multi-entry sanity

    @Test("Adding an entry changes the hash")
    func addingEntryChangesHash() {
        let a = makeOrderedEntry(id: "a")
        let b = makeOrderedEntry(id: "b")
        #expect([a].computeHashValue() != [a, b].computeHashValue())
    }

    @Test("Mutating one entry inside a multi-entry array changes the hash")
    func mutatingOneEntryInMultiEntryArrayChangesHash() {
        let a = makeOrderedEntry(id: "a")
        let b = makeOrderedEntry(id: "b", name: "Original")
        let bPrime = makeOrderedEntry(id: "b", name: "Mutated")
        #expect([a, b].computeHashValue() != [a, bPrime].computeHashValue())
    }
}
