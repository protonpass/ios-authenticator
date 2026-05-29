//
// BackUpManagerTests.swift
// Proton Authenticator - Created on 29/05/2026.
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
import DataLayer
import Foundation
import Testing

@Suite(.tags(.tooling))
@MainActor
struct BackUpManagerTests {
    let keychain: MockKeychainService
    let settings: MockSettingsService

    init() {
        keychain = MockKeychainService()
        settings = MockSettingsService()
    }

    // MARK: - Helpers

    /// Creates a unique temporary directory; cleanup is the caller's responsibility (via `defer`).
    private func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeBookmark(for url: URL) throws -> Data {
        let options: URL.BookmarkCreationOptions = ProcessInfo.processInfo.isiOSAppOnMac
            ? .macSecurityScope
            : .minimalBookmark
        return try url.bookmarkData(options: options,
                                    includingResourceValuesForKeys: nil,
                                    relativeTo: nil)
    }

    private func makeSUT(maxBackupCount: Int = 5) -> BackUpManager {
        BackUpManager(maxBackupCount: maxBackupCount,
                      keychainService: keychain,
                      settingsService: settings,
                      logger: MockLogger())
    }

    // MARK: - restoreDestinationFolder() on init

    @Test("Restores the destination folder from a Keychain bookmark on init")
    func restoresFromKeychainOnInit() throws {
        let tmp = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tmp) }
        settings.folderBackup = true
        try keychain.set(makeBookmark(for: tmp),
                         for: AppConstants.Settings.backupFolderBookmark,
                         shouldSync: false)

        let sut = makeSUT()

        #expect(sut.destinationFolderURL?.lastPathComponent == tmp.lastPathComponent)
        #expect(settings.folderBackup == true)
    }

    @Test("Migrates a legacy UserDefaults bookmark into the Keychain on init")
    func migratesLegacyBookmarkOnInit() throws {
        let tmp = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tmp) }
        settings.folderBackup = true
        settings.backupFolderBookmark = try makeBookmark(for: tmp) // legacy location

        let sut = makeSUT()

        #expect(settings.backupFolderBookmark == nil) // cleared from UserDefaults
        let migrated: Data? = try? keychain.get(keyId: AppConstants.Settings.backupFolderBookmark,
                                                isSynced: false)
        #expect(migrated != nil) // moved into the Keychain
        #expect(sut.destinationFolderURL?.lastPathComponent == tmp.lastPathComponent)
        #expect(settings.folderBackup == true)
    }

    @Test("Is a no-op on init when folder backup is disabled")
    func disabledFolderBackupIsNoOpOnInit() {
        settings.folderBackup = false

        let sut = makeSUT()

        #expect(sut.destinationFolderURL == nil)
        #expect(settings.folderBackup == false)
    }

    @Test("Disables folder backup on init when no bookmark is stored")
    func missingBookmarkDisablesOnInit() {
        settings.folderBackup = true // enabled but nothing persisted

        let sut = makeSUT()

        #expect(sut.destinationFolderURL == nil)
        #expect(settings.folderBackup == false)
    }

    @Test("Disables folder backup on init when the stored bookmark is unusable")
    func corruptBookmarkDisablesOnInit() throws {
        settings.folderBackup = true
        try keychain.set(Data("not-a-real-bookmark".utf8),
                         for: AppConstants.Settings.backupFolderBookmark,
                         shouldSync: false)

        let sut = makeSUT()

        #expect(sut.destinationFolderURL == nil)
        #expect(settings.folderBackup == false)
    }

    // MARK: - saveDestinationFolder()

    @Test("saveDestinationFolder persists the bookmark, sets the URL, and enables folder backup")
    func saveDestinationFolderPersistsEverything() throws {
        let tmp = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let sut = makeSUT() // folderBackup defaults to false -> init restore is a no-op

        try sut.saveDestinationFolder(tmp)

        #expect(sut.destinationFolderURL == tmp)
        #expect(settings.folderBackup == true)
        let stored: Data? = try? keychain.get(keyId: AppConstants.Settings.backupFolderBookmark,
                                              isSynced: false)
        #expect(stored != nil)
    }

    // MARK: - clearDestinationFolder()

    @Test("clearDestinationFolder removes the bookmark, the URL, and disables folder backup")
    func clearDestinationFolderResetsEverything() throws {
        let tmp = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let sut = makeSUT()
        try sut.saveDestinationFolder(tmp)

        sut.clearDestinationFolder()

        #expect(sut.destinationFolderURL == nil)
        #expect(settings.folderBackup == false)
        #expect(throws: (any Error).self) {
            let _: Data = try keychain.get(keyId: AppConstants.Settings.backupFolderBookmark,
                                           isSynced: false)
        }
    }
}
