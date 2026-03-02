//
// EntryDataServiceBackupTests.swift
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

import CommonUtilities
@testable import DataLayer
import Foundation
import Models
import Testing

@Suite(.tags(.service))
@MainActor
struct EntryDataServiceBackupTests {
    let sut: EntryDataService
    let mockBackUpManager: MockBackUpManager
    let mockSettings: MockSettingsService
    let mockKeychain: MockKeychainService
    let mockRepository: MockEntryRepository
    let mockTotpGenerator: MockTotpGenerator

    init() {
        let repository = MockEntryRepository()
        let settings = MockSettingsService()
        let keychain = MockKeychainService()
        let backUpManager = MockBackUpManager()
        let totpGenerator = MockTotpGenerator()

        mockRepository = repository
        mockSettings = settings
        mockKeychain = keychain
        mockBackUpManager = backUpManager
        mockTotpGenerator = totpGenerator

        sut = EntryDataService(
            repository: repository,
            importService: MockImportingService(),
            totpGenerator: totpGenerator,
            totpIssuerMapper: MockTotpIssuerMapper(),
            logger: MockLogger(),
            reachabilityManager: MockReachabilityManager(),
            backUpManager: backUpManager,
            settings: settings,
            keychainService: keychain,
            syncOperation: MockSyncOperationChecker()
        )
    }

    // MARK: - Helpers

    private func makeEntry(id: String = "test-id", name: String = "Test") -> Entry {
        Entry(id: id, name: name,
              uri: "otpauth://totp/\(name)?secret=ABCDEFGH&issuer=TestIssuer",
              period: 30, issuer: "TestIssuer", secret: "ABCDEFGH", type: .totp, note: nil)
    }

    private func makeUiModel(entry: Entry, order: Int = 0) -> EntryUiModel {
        let code = Code(current: "123456", next: "654321", entry: entry)
        let orderedEntry = OrderedEntry(entry: entry, keyId: nil, remoteId: nil,
                                        order: order, modifiedTime: Date.now.timeIntervalSince1970,
                                        revision: 0, contentFormatVersion: 1)
        return EntryUiModel(orderedEntry: orderedEntry, code: code, issuerInfo: nil)
    }

    private func prepareForBackup(entries: [EntryUiModel]) throws {
        sut.updateData(entries)
        mockSettings.folderBackup = true
        try mockKeychain.set("test-password", for: AppConstants.Settings.backupPassword, shouldSync: false)
    }

    // MARK: - backUpEntries() unit tests

    @Test("backUpEntries does nothing when document backup is disabled")
    func backUpEntries_whenDocumentBackupDisabled_doesNotCallWrite() throws {
        let entry = makeEntry()
        sut.updateData([makeUiModel(entry: entry)])
        mockSettings.folderBackup = false

        sut.backUpEntries()

        #expect(mockBackUpManager.writeCalled == 0)
        #expect(mockRepository.exportCalled == 0)
    }

    @Test("backUpEntries writes backup when enabled with password")
    func backUpEntries_whenEnabled_callsWrite() throws {
        let entry = makeEntry()
        let uiModel = makeUiModel(entry: entry)
        try prepareForBackup(entries: [uiModel])

        sut.backUpEntries()

        #expect(mockBackUpManager.writeCalled == 1)
        #expect(mockBackUpManager.lastWrittenData != nil)
        // Verify the written data matches the export result
        let expectedData = mockRepository.exportResult.data(using: .utf8)
        #expect(mockBackUpManager.lastWrittenData == expectedData)
    }

    @Test("backUpEntries exports the correct entries from current data state")
    func backUpEntries_exportsCorrectEntries() throws {
        let entry1 = makeEntry(id: "id-1", name: "First")
        let entry2 = makeEntry(id: "id-2", name: "Second")
        try prepareForBackup(entries: [
            makeUiModel(entry: entry1, order: 0),
            makeUiModel(entry: entry2, order: 1)
        ])

        sut.backUpEntries()

        // Verify export was called with exactly the entries in dataState
        #expect(mockRepository.lastExportedEntries.count == 2)
        #expect(mockRepository.lastExportedEntries.map(\.id) == ["id-1", "id-2"])
        #expect(mockRepository.lastExportPassword == "test-password")
    }

    @Test("backUpEntries does not throw when no password in keychain")
    func backUpEntries_whenNoPasswordInKeychain_doesNotThrow() {
        let entry = makeEntry()
        sut.updateData([makeUiModel(entry: entry)])
        mockSettings.folderBackup = true
        // No password set in keychain

        sut.backUpEntries()

        #expect(mockBackUpManager.writeCalled == 0)
    }

    @Test("backUpEntries does not throw when write fails")
    func backUpEntries_whenWriteFails_doesNotThrow() throws {
        let entry = makeEntry()
        try prepareForBackup(entries: [makeUiModel(entry: entry)])
        mockBackUpManager.writeError = NSError(domain: "test", code: 1)

        sut.backUpEntries()

        #expect(mockBackUpManager.writeCalled == 1)
    }

    // MARK: - Mutation triggers backup with correct file content

    @Test("update: backup file contains the updated entry")
    func update_backupFileReflectsUpdatedEntry() async throws {
        let entry = makeEntry(id: "entry-1", name: "Original")
        try prepareForBackup(entries: [makeUiModel(entry: entry, order: 0)])

        let params = EntryParameters.totp(
            TotpParams(name: "Updated", secret: "ABCDEFGH", issuer: "TestIssuer",
                       period: 30, digits: 6, algorithm: .sha1, note: nil)
        )

        try await sut.updateAndRefreshEntry(for: "entry-1", with: params)

        // Backup was written
        #expect(mockBackUpManager.writeCalled == 1)
        #expect(mockRepository.completeUpdateCalled == 1)
        // File content matches the export output
        #expect(mockBackUpManager.lastWrittenData == mockRepository.exportResult.data(using: .utf8))
        // Export received the updated entry, not the old one
        #expect(mockRepository.lastExportedEntries.count == 1)
        #expect(mockRepository.lastExportedEntries.first?.name == "Updated")
        #expect(mockRepository.lastExportPassword == "test-password")
    }

    @Test("update: no backup file written on failure")
    func update_noBackupOnFailure() async throws {
        let entry = makeEntry(id: "entry-1", name: "Original")
        try prepareForBackup(entries: [makeUiModel(entry: entry, order: 0)])
        mockRepository.completeUpdateError = NSError(domain: "test", code: 1)

        let params = EntryParameters.totp(
            TotpParams(name: "Updated", secret: "ABCDEFGH", issuer: "TestIssuer",
                       period: 30, digits: 6, algorithm: .sha1, note: nil)
        )

        await #expect(throws: Error.self) {
            try await sut.updateAndRefreshEntry(for: "entry-1", with: params)
        }

        #expect(mockBackUpManager.writeCalled == 0)
        #expect(mockBackUpManager.lastWrittenData == nil)
    }

    @Test("delete: backup file contains only the remaining entries")
    func delete_backupFileReflectsRemainingEntries() async throws {
        let entry1 = makeEntry(id: "entry-1", name: "ToDelete")
        let entry2 = makeEntry(id: "entry-2", name: "ToKeep")
        try prepareForBackup(entries: [
            makeUiModel(entry: entry1, order: 0),
            makeUiModel(entry: entry2, order: 1)
        ])

        try await sut.delete(makeUiModel(entry: entry1, order: 0))

        // Backup was written
        #expect(mockBackUpManager.writeCalled == 1)
        #expect(mockRepository.completeRemovesCalled == 1)
        // File content matches the export output
        #expect(mockBackUpManager.lastWrittenData == mockRepository.exportResult.data(using: .utf8))
        // Export received only the surviving entry
        #expect(mockRepository.lastExportedEntries.count == 1)
        #expect(mockRepository.lastExportedEntries.first?.id == "entry-2")
    }

    @Test("delete: no backup file written on failure")
    func delete_noBackupOnFailure() async throws {
        let entry = makeEntry(id: "entry-1")
        let uiModel = makeUiModel(entry: entry, order: 0)
        try prepareForBackup(entries: [uiModel])
        mockRepository.completeRemovesError = NSError(domain: "test", code: 1)

        await #expect(throws: Error.self) {
            try await sut.delete(uiModel)
        }

        #expect(mockBackUpManager.writeCalled == 0)
        #expect(mockBackUpManager.lastWrittenData == nil)
    }

    @Test("reorder: backup file contains entries in the new order")
    func reorder_backupFileReflectsNewOrder() async throws {
        let entry1 = makeEntry(id: "entry-1", name: "First")
        let entry2 = makeEntry(id: "entry-2", name: "Second")
        try prepareForBackup(entries: [
            makeUiModel(entry: entry1, order: 0),
            makeUiModel(entry: entry2, order: 1)
        ])

        try await sut.reorderItem(from: 0, to: 1)

        // Backup was written
        #expect(mockBackUpManager.writeCalled == 1)
        #expect(mockRepository.completeReorderCalled == 1)
        // File content matches the export output
        #expect(mockBackUpManager.lastWrittenData == mockRepository.exportResult.data(using: .utf8))
        // Export received entries in the new order (Second first, then First)
        #expect(mockRepository.lastExportedEntries.count == 2)
        #expect(mockRepository.lastExportedEntries.map(\.id) == ["entry-2", "entry-1"])
    }

    @Test("reorder: no backup file written on failure")
    func reorder_noBackupOnFailure() async throws {
        let entry1 = makeEntry(id: "entry-1", name: "First")
        let entry2 = makeEntry(id: "entry-2", name: "Second")
        try prepareForBackup(entries: [
            makeUiModel(entry: entry1, order: 0),
            makeUiModel(entry: entry2, order: 1)
        ])
        mockRepository.completeReorderError = NSError(domain: "test", code: 1)

        await #expect(throws: Error.self) {
            try await sut.reorderItem(from: 0, to: 1)
        }

        #expect(mockBackUpManager.writeCalled == 0)
        #expect(mockBackUpManager.lastWrittenData == nil)
    }
}
