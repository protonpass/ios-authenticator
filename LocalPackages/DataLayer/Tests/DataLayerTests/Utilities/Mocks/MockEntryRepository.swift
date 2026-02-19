//
// MockEntryRepository.swift
// Proton Authenticator - Created on 19/02/2026.
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

import AuthenticatorRustCore
@testable import DataLayer
import Foundation
import Models

final class MockEntryRepository: @unchecked Sendable, EntryRepositoryProtocol {
    // MARK: - Configurable results

    var exportResult = "exported-data"
    var exportError: Error?
    var generateCodesError: Error?
    var completeSaveResult: [RemoteEncryptedEntry]?
    var completeSaveError: Error?
    var completeUpdateError: Error?
    var completeRemovesError: Error?
    var completeReorderError: Error?
    var allLocalEntries: [EntryState] = []
    var createTotpEntryResult: Entry?
    var createSteamEntryResult: Entry?

    // MARK: - Call tracking

    private(set) var exportCalled = 0
    private(set) var lastExportedEntries: [Entry] = []
    private(set) var lastExportPassword: String?
    private(set) var completeSaveCalled = 0
    private(set) var completeUpdateCalled = 0
    private(set) var completeRemovesCalled = 0
    private(set) var completeReorderCalled = 0
    private(set) var generateCodesCalled = 0
    private(set) var localReorderCalled = 0

    // MARK: - EntryRepositoryProtocol

    func entry(for uri: String) async throws -> Entry {
        Entry(id: UUID().uuidString, name: "Test", uri: uri, period: 30,
              issuer: "Test", secret: "SECRET", type: .totp, note: nil)
    }

    func export(entries: [Entry]) throws -> String {
        exportCalled += 1
        lastExportedEntries = entries
        lastExportPassword = nil
        if let exportError { throw exportError }
        return exportResult
    }

    func export(entries: [Entry], with password: String) throws -> String {
        exportCalled += 1
        lastExportedEntries = entries
        lastExportPassword = password
        if let exportError { throw exportError }
        return exportResult
    }

    func generateCodes(entries: [Entry], time: TimeInterval) throws -> [Code] {
        generateCodesCalled += 1
        if let generateCodesError { throw generateCodesError }
        return entries.map { Code(current: "123456", next: "654321", entry: $0) }
    }

    func createSteamEntry(params: SteamParams) throws -> Entry {
        if let result = createSteamEntryResult { return result }
        return Entry(id: UUID().uuidString, name: params.name, uri: "", period: 30,
                     issuer: "Steam", secret: "", type: .steam, note: nil)
    }

    func createTotpEntry(params: TotpParams) throws -> Entry {
        if let result = createTotpEntryResult { return result }
        return Entry(id: UUID().uuidString, name: params.name,
                     uri: "otpauth://totp/\(params.name)?secret=\(params.secret)",
                     period: params.period ?? 30,
                     issuer: params.issuer, secret: params.secret, type: .totp, note: nil)
    }

    func serialize(entries: [Entry]) throws -> [Data] { [] }

    func deserialize(serializedData: [Data]) throws -> [Entry] { [] }

    func getTotpParams(entry: Entry) throws -> TotpParams {
        TotpParams(name: entry.name, secret: entry.secret, issuer: entry.issuer,
                   period: entry.period, digits: 6, algorithm: .sha1, note: entry.note)
    }

    @MainActor
    func getAllLocalEntries() async throws -> [EntryState] {
        allLocalEntries
    }

    @MainActor
    func localUpsert(_ entries: [OrderedEntry]) async throws {}

    @MainActor
    func localRemoves(_ entriesId: [String]) async throws {}

    @MainActor
    func localRemoveAll() async throws {}

    @MainActor
    func localUpdate(_ entry: OrderedEntry) async throws -> OrderedEntry? { nil }

    @MainActor
    func localReorder(_ entries: [OrderedEntry]) async throws {
        localReorderCalled += 1
    }

    func unsyncAllEntries() async throws {}

    func reset(keyIds: [String]) async throws {}

    func resetRemoteKeys() async {}

    func getAllLocalEncryptedEntries() async throws -> [EncryptedEntryEntity] { [] }

    func remoteSave(entries: [OrderedEntry]) async throws -> [RemoteEncryptedEntry] { [] }

    func remoteUpdate(entry: OrderedEntry) async throws -> RemoteEncryptedEntry {
        fatalError("Not expected in backup tests")
    }

    func remoteUpdates(entries: [OrderedEntry]) async throws -> [RemoteEncryptedEntry] { [] }

    func remoteDeletes(remoteEntryIds: [String]) async throws {}

    func singleItemRemoteReordering(entryId: String, entries: [OrderedEntry]) async throws {}

    func batchRemoteReordering(entries: [OrderedEntry]) async throws {}

    func fetchAllRemoteEntries() async throws -> [OrderedEntry] { [] }

    func fetchRemoteEncryptionKeyOrPushLocalKey() async throws {}

    func completeSave(entries: [OrderedEntry]) async throws -> [RemoteEncryptedEntry]? {
        completeSaveCalled += 1
        if let completeSaveError { throw completeSaveError }
        return completeSaveResult
    }

    func completeRemoves(entries: [OrderedEntry]) async throws {
        completeRemovesCalled += 1
        if let completeRemovesError { throw completeRemovesError }
    }

    func completeUpdate(entry: OrderedEntry, oldEntry: OrderedEntry) async throws {
        completeUpdateCalled += 1
        if let completeUpdateError { throw completeUpdateError }
    }

    func completeReorder(entries: [OrderedEntry]) async throws {
        completeReorderCalled += 1
        if let completeReorderError { throw completeReorderError }
    }
}
