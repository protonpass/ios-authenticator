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

    private func makeEntryState(entry: Entry, order: Int = 0) -> EntryState {
        let orderedEntry = OrderedEntry(entry: entry, keyId: "key-id", remoteId: nil,
                                        order: order, modifiedTime: Date.now.timeIntervalSince1970,
                                        revision: 0, contentFormatVersion: 1)
        let entity = EncryptedEntryEntity(id: entry.id,
                                          encryptedData: Data(),
                                          remoteId: "",
                                          keyId: "key-id",
                                          order: order,
                                          syncState: .unsynced,
                                          creationDate: Date.now.timeIntervalSince1970,
                                          modifiedTime: Date.now.timeIntervalSince1970)
        return .decrypted(entity.encryptedEntry, orderedEntry)
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
        mockBackUpManager.writeError = EntryServiceTestError.failTest

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
        mockRepository.completeUpdateError = EntryServiceTestError.failTest

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
        mockRepository.completeRemovesError = EntryServiceTestError.failTest

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
        mockRepository.completeReorderError = EntryServiceTestError.failTest

        await #expect(throws: Error.self) {
            try await sut.reorderItem(from: 0, to: 1)
        }

        #expect(mockBackUpManager.writeCalled == 0)
        #expect(mockBackUpManager.lastWrittenData == nil)
    }

    // MARK: - Load path (iCloud-pushed changes flow through here)

    @Test("loadEntries: backup file reflects entries fetched from local storage")
    func loadEntries_whenFolderBackupEnabled_writesBackup() async throws {
        // Simulates iCloud (or any source) populating the local store; loadEntries should
        // propagate the new state to the backup file even when no explicit mutation occurred.
        let entry1 = makeEntry(id: "entry-1", name: "First")
        let entry2 = makeEntry(id: "entry-2", name: "Second")
        mockRepository.allLocalEntries = [
            makeEntryState(entry: entry1, order: 0),
            makeEntryState(entry: entry2, order: 1)
        ]
        mockSettings.folderBackup = true
        mockSettings.iCloudSync = true
        try mockKeychain.set("test-password",
                             for: AppConstants.Settings.backupPassword,
                             shouldSync: false)

        await sut.loadEntries()

        #expect(mockBackUpManager.writeCalled == 1)
        #expect(mockBackUpManager.lastWrittenData == mockRepository.exportResult.data(using: .utf8))
        #expect(mockRepository.lastExportedEntries.map(\.id) == ["entry-1", "entry-2"])
        #expect(mockRepository.lastExportPassword == "test-password")
    }

    @Test("loadEntries: no backup file written when folder backup is disabled")
    func loadEntries_whenFolderBackupDisabled_doesNotWriteBackup() async {
        let entry = makeEntry()
        mockRepository.allLocalEntries = [makeEntryState(entry: entry)]
        mockSettings.folderBackup = false

        await sut.loadEntries()

        #expect(mockBackUpManager.writeCalled == 0)
    }

    @Test("loadEntries: no backup file written when load fails")
    func loadEntries_whenLoadFails_doesNotWriteBackup() async throws {
        mockSettings.folderBackup = true
        try mockKeychain.set("test-password",
                             for: AppConstants.Settings.backupPassword,
                             shouldSync: false)

        await sut.loadEntries()

        #expect(mockBackUpManager.writeCalled == 0)
    }

    @Test("unsyncAllEntries: backup file is written when folder backup is enabled")
    func unsyncAllEntries_whenFolderBackupEnabled_writesBackup() async throws {
        let entry = makeEntry()
        mockRepository.allLocalEntries = [makeEntryState(entry: entry)]
        mockSettings.folderBackup = true
        try mockKeychain.set("test-password",
                             for: AppConstants.Settings.backupPassword,
                             shouldSync: false)

        try await sut.unsyncAllEntries()

        #expect(mockRepository.unsyncAllEntriesCalled == 1)
        #expect(mockBackUpManager.writeCalled == 1)
        #expect(mockBackUpManager.lastWrittenData == mockRepository.exportResult.data(using: .utf8))
    }

    @Test("unsyncAllEntries: no backup file written when unsync fails")
    func unsyncAllEntries_whenUnsyncFails_doesNotWriteBackup() async throws {
        mockRepository.unsyncAllEntriesError = EntryServiceTestError.failTest
        mockSettings.folderBackup = true
        try mockKeychain.set("test-password",
                             for: AppConstants.Settings.backupPassword,
                             shouldSync: false)

        await #expect(throws: Error.self) {
            try await sut.unsyncAllEntries()
        }

        #expect(mockBackUpManager.writeCalled == 0)
    }

    // MARK: - Hash cache (skip redundant writes on load/foreground)

    @Test("backUpEntries: skips a second write when entries are unchanged")
    func backUpEntries_whenContentUnchanged_skipsSecondWrite() throws {
        let entry = makeEntry()
        try prepareForBackup(entries: [makeUiModel(entry: entry, order: 0)])

        let first = sut.backUpEntries()
        let second = sut.backUpEntries()

        #expect(mockBackUpManager.writeCalled == 1)
        if case .successful = first { } else { Issue.record("expected first write to be .successful") }
        if case .unchanged = second { } else { Issue.record("expected second call to be .unchanged") }
    }

    @Test("backUpEntries: writes again after content changes")
    func backUpEntries_whenContentChanges_writesAgain() throws {
        let entry1 = makeEntry(id: "entry-1", name: "First")
        try prepareForBackup(entries: [makeUiModel(entry: entry1, order: 0)])

        sut.backUpEntries()

        // Mutate the data state to a different shape (new entry appended).
        let entry2 = makeEntry(id: "entry-2", name: "Second")
        sut.updateData([
            makeUiModel(entry: entry1, order: 0),
            makeUiModel(entry: entry2, order: 1)
        ])

        let result = sut.backUpEntries()

        #expect(mockBackUpManager.writeCalled == 2)
        if case .successful = result { } else { Issue.record("expected second write to be .successful") }
    }

    @Test("backUpEntries: skips when only TOTP code changes (not entry content)")
    func backUpEntries_whenOnlyCodeChanges_skipsWrite() throws {
        let entry = makeEntry()
        try prepareForBackup(entries: [makeUiModel(entry: entry, order: 0)])

        sut.backUpEntries()

        // Replace just the code on the same entry; entry data, order, revision unchanged.
        // This simulates the TOTP rotation re-render path that shouldn't trigger backups.
        let original = sut.dataState.data ?? []
        let rotated = original.map { $0.updateCode(Code(current: "999999", next: "888888", entry: $0.orderedEntry.entry)) }
        sut.updateData(rotated)

        let result = sut.backUpEntries()

        #expect(mockBackUpManager.writeCalled == 1)
        if case .unchanged = result { } else { Issue.record("expected .unchanged result") }
    }

    @Test("backUpEntries(force: true): always writes even when content is unchanged")
    func backUpEntries_forceTrue_bypassesCache() throws {
        let entry = makeEntry()
        try prepareForBackup(entries: [makeUiModel(entry: entry, order: 0)])

        sut.backUpEntries()
        let forced = sut.backUpEntries(force: true)

        #expect(mockBackUpManager.writeCalled == 2)
        if case .successful = forced { } else { Issue.record("expected forced call to be .successful") }
    }

    @Test("backUpEntries: failed write does not poison the cache")
    func backUpEntries_whenWriteFails_doesNotCacheHash() throws {
        let entry = makeEntry()
        try prepareForBackup(entries: [makeUiModel(entry: entry, order: 0)])
        let preCallHash = mockSettings.lastBackupHash
        mockBackUpManager.writeError = EntryServiceTestError.failTest

        let failed = sut.backUpEntries()
        #expect(mockBackUpManager.writeCalled == 1)
        if case .error = failed { } else { Issue.record("expected failed write to return .error") }
        // Hash must NOT have been persisted on failure, otherwise a single transient
        // failure would leave the backup permanently stale until something else changes.
        #expect(mockSettings.lastBackupHash == preCallHash)

        mockBackUpManager.writeError = nil
        let retry = sut.backUpEntries()

        #expect(mockBackUpManager.writeCalled == 2)
        if case .successful = retry { } else { Issue.record("expected retry to be .successful") }
        #expect(mockSettings.lastBackupHash != nil)
    }

    @Test("loadEntries: second consecutive load with same data skips the backup write")
    func loadEntries_whenCalledTwiceWithSameData_writesOnceOnly() async throws {
        let entry = makeEntry()
        mockRepository.allLocalEntries = [makeEntryState(entry: entry)]
        mockSettings.folderBackup = true
        mockSettings.iCloudSync = true
        try mockKeychain.set("test-password",
                             for: AppConstants.Settings.backupPassword,
                             shouldSync: false)

        await sut.loadEntries()
        await sut.loadEntries()

        // Models the foreground/background cycle that previously rewrote today's backup
        // file every time the app came back to the foreground.
        #expect(mockBackUpManager.writeCalled == 1)
    }

    // MARK: - Persisted hash across cold launches

    @Test("first launch: lastBackedUpHash is nil → write and persist the digest")
    func backUpEntries_firstLaunch_persistsHash() throws {
        let entry = makeEntry()
        try prepareForBackup(entries: [makeUiModel(entry: entry, order: 0)])
        #expect(mockSettings.lastBackupHash == nil)

        sut.backUpEntries()

        #expect(mockBackUpManager.writeCalled == 1)
        #expect(mockSettings.lastBackupHash != nil)
        // SHA-256 hex digest is 64 lowercase hex characters.
        #expect(mockSettings.lastBackupHash?.count == 64)
        #expect(mockSettings.lastBackupHash?.allSatisfy { $0.isHexDigit && (!$0.isLetter || $0.isLowercase) } == true)
    }

    @Test("cold launch: persisted hash matches current data → skip without writing")
    func backUpEntries_coldLaunchMatchingHash_skipsWrite() throws {
        // First instance writes and persists a hash...
        let entry = makeEntry()
        try prepareForBackup(entries: [makeUiModel(entry: entry, order: 0)])
        sut.backUpEntries()
        let persistedHash = try #require(mockSettings.lastBackupHash)
        #expect(mockBackUpManager.writeCalled == 1)

        // ...then a brand-new EntryDataService instance shares the same settings/keychain
        // (UserDefaults survives process restarts). This simulates a cold relaunch with
        // identical data and must NOT write a new file.
        let coldSut = EntryDataService(repository: mockRepository,
                                       importService: MockImportingService(),
                                       totpGenerator: mockTotpGenerator,
                                       totpIssuerMapper: MockTotpIssuerMapper(),
                                       logger: MockLogger(),
                                       reachabilityManager: MockReachabilityManager(),
                                       backUpManager: mockBackUpManager,
                                       settings: mockSettings,
                                       keychainService: mockKeychain,
                                       syncOperation: MockSyncOperationChecker())
        coldSut.updateData([makeUiModel(entry: entry, order: 0)])

        let result = coldSut.backUpEntries()

        #expect(mockBackUpManager.writeCalled == 1)
        #expect(mockSettings.lastBackupHash == persistedHash)
        if case .unchanged = result { } else { Issue.record("expected .unchanged on cold relaunch") }
    }

    @Test("cold launch: persisted hash differs from current data → write and update")
    func backUpEntries_coldLaunchStaleHash_writesAndUpdatesPersistedHash() throws {
        let entry = makeEntry()
        try prepareForBackup(entries: [makeUiModel(entry: entry, order: 0)])
        // Pre-seed the persisted state with a stale digest, as if data had changed while
        // the app was killed (e.g. iCloud merged changes from another device).
        mockSettings.lastBackupHash = String(repeating: "0", count: 64)

        let result = sut.backUpEntries()

        #expect(mockBackUpManager.writeCalled == 1)
        if case .successful = result { } else { Issue.record("expected .successful when stale hash differs") }
        #expect(mockSettings.lastBackupHash != String(repeating: "0", count: 64))
        #expect(mockSettings.lastBackupHash?.count == 64)
    }

    @Test("computeEntriesHash: digest is stable across two fresh EntryDataService instances")
    func computeEntriesHash_isDeterministicAcrossInstances() throws {
        let entry = makeEntry()
        try prepareForBackup(entries: [makeUiModel(entry: entry, order: 0)])
        sut.backUpEntries()
        let firstHash = try #require(mockSettings.lastBackupHash)

        // New service instance, same persisted state and same data → should compute the
        // exact same digest (this is what makes cold-launch comparison meaningful).
        let secondSut = EntryDataService(repository: mockRepository,
                                         importService: MockImportingService(),
                                         totpGenerator: mockTotpGenerator,
                                         totpIssuerMapper: MockTotpIssuerMapper(),
                                         logger: MockLogger(),
                                         reachabilityManager: MockReachabilityManager(),
                                         backUpManager: mockBackUpManager,
                                         settings: mockSettings,
                                         keychainService: mockKeychain,
                                         syncOperation: MockSyncOperationChecker())
        secondSut.updateData([makeUiModel(entry: entry, order: 0)])
        // Bypass cache so we actually exercise the digest computation + write path.
        mockSettings.lastBackupHash = nil
        secondSut.backUpEntries()
        let secondHash = try #require(mockSettings.lastBackupHash)

        #expect(firstHash == secondHash)
    }
}

enum EntryServiceTestError : Error {
    case failTest
}
