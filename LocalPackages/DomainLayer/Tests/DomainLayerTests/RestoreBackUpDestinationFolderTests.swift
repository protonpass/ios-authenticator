//
// RestoreBackUpDestinationFolderTests.swift
// Proton Authenticator - Created on 27/05/2026.
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
import DomainLayer
import Foundation
import Models
import Testing

@MainActor
struct RestoreBackUpDestinationFolderTests {
    let backUpManager: MockBackUpManager
    let settingsService: MockedSettingsService
    let keychainService: MockKeychainService
    let sut: any RestoreBackUpDestinationFolderUseCase

    init() {
        backUpManager = .init()
        settingsService = .init()
        keychainService = .init()
        sut = RestoreBackUpDestinationFolder(backUpManager: backUpManager,
                                             settingsService: settingsService,
                                             keychainService: keychainService,
                                             logger: MockLogger())
    }

    @Test("Returns nil and is a no-op when folderBackup is disabled")
    func folderBackupDisabledIsNoOp() {
        settingsService.folderBackup = false

        let result = sut.execute()

        #expect(result == nil)
        #expect(backUpManager.resolveDestinationFolderCalled == 0)
        #expect(keychainService.getCallCount == 0)
    }

    @Test("Migrates legacy UserDefaults bookmark into the Keychain")
    func migratesLegacyBookmarkIntoKeychain() throws {
        settingsService.folderBackup = true
        let legacyBookmark = Data("legacy".utf8)
        settingsService.backupFolderBookmark = legacyBookmark

        let result = sut.execute()

        #expect(result != nil)
        #expect(settingsService.backupFolderBookmark == nil)
        #expect(keychainService.setCallCount == 1)
        #expect(backUpManager.resolveDestinationFolderCalled == 1)
        #expect(backUpManager.lastResolvedBookmark == legacyBookmark)
    }

    @Test("Resolves bookmark from Keychain and returns the URL on success")
    func happyPathResolvesBookmark() throws {
        settingsService.folderBackup = true
        let bookmark = Data("bookmark".utf8)
        try keychainService.set(bookmark,
                                for: AppConstants.Settings.backupFolderBookmark,
                                shouldSync: false)
        let expectedURL = URL(fileURLWithPath: "/tmp/restored")
        backUpManager.resolvedURL = expectedURL

        let result = sut.execute()

        #expect(result == expectedURL)
        #expect(backUpManager.resolveDestinationFolderCalled == 1)
        #expect(backUpManager.lastResolvedBookmark == bookmark)
        #expect(settingsService.folderBackup == true)
    }

    @Test("Disables folderBackup when bookmark is stale")
    func staleBookmarkDisablesFolderBackup() throws {
        settingsService.folderBackup = true
        try keychainService.set(Data("bookmark".utf8),
                                for: AppConstants.Settings.backupFolderBookmark,
                                shouldSync: false)
        backUpManager.resolveError = AuthError.backup(.staleBookmark)

        let result = sut.execute()

        #expect(result == nil)
        #expect(settingsService.folderBackup == false)
    }

    @Test("Disables folderBackup when no bookmark is stored")
    func missingBookmarkDisablesFolderBackup() {
        settingsService.folderBackup = true
        // No bookmark seeded in keychain and no legacy data in settings.

        let result = sut.execute()

        #expect(result == nil)
        #expect(settingsService.folderBackup == false)
        #expect(backUpManager.resolveDestinationFolderCalled == 0)
    }

    @Test("Second call after a failure short-circuits via the folderBackup guard")
    func idempotentSecondCallAfterFailure() {
        settingsService.folderBackup = true
        // No bookmark -> first call fails and disables folderBackup.
        _ = sut.execute()
        #expect(settingsService.folderBackup == false)

        let result = sut.execute()

        #expect(result == nil)
        // No additional resolve attempt after the guard short-circuits.
        #expect(backUpManager.resolveDestinationFolderCalled == 0)
    }
}
