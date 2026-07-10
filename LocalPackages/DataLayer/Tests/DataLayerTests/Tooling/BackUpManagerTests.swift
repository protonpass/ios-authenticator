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
import Models
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

    /// Writes a file into `directory`, optionally back-dating its creation date so rotation
    /// ordering is deterministic.
    @discardableResult
    private func makeFile(named name: String,
                          in directory: URL,
                          contents: String = "x",
                          creationDate: Date? = nil) throws -> URL {
        let url = directory.appendingPathComponent(name)
        try Data(contents.utf8).write(to: url)
        if let creationDate {
            try FileManager.default.setAttributes([.creationDate: creationDate],
                                                  ofItemAtPath: url.path)
        }
        return url
    }

    /// The exact naming convention the app uses for its own backups.
    private func ownedBackupName(_ day: String) -> String {
        "Proton_Authenticator_backup_\(day).json"
    }

    private func exists(_ name: String, in directory: URL) -> Bool {
        FileManager.default.fileExists(atPath: directory.appendingPathComponent(name).path)
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

    // MARK: - File ownership (data-loss prevention)
    //
    // The backup folder can be any user-chosen directory (e.g. an iCloud folder shared with other
    // apps). The manager must only ever list, rotate, or delete files it created itself, which
    // always follow the "Proton_Authenticator_backup_<yyyy-MM-dd>.json" convention.

    @Test("Automatic backup rotation never deletes files the app did not create")
    func rotationPreservesForeignFiles() throws {
        let tmp = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tmp) }

        // Foreign backups from other apps already in the folder, plus a non-JSON file.
        let foreignNames = [
            "other_app_backup_2024-01-01.json",
            "aegis-backup.json",
            "2fas-2024.json",
            "vault.json",
            "notes.txt"
        ]
        for name in foreignNames {
            try makeFile(named: name, in: tmp)
        }

        // maxBackupCount = 1 makes the (pre-fix) bug delete *every* pre-existing file on first write.
        let sut = makeSUT(maxBackupCount: 1)
        try sut.saveDestinationFolder(tmp)

        try sut.write(data: Data("backup".utf8))

        for name in foreignNames {
            #expect(exists(name, in: tmp),
                    "Foreign file \(name) must never be deleted by backup rotation")
        }
    }

    @Test("Rotation trims only the app's own backups, keeping foreign files intact")
    func rotationTrimsOnlyOwnedFiles() throws {
        let tmp = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tmp) }

        // Three of our own backups, oldest first. Distinct, increasing creation dates make the
        // rotation order deterministic and keep them older than the foreign files created below.
        let base = Date(timeIntervalSinceReferenceDate: 0)
        let owned = [
            ownedBackupName("2026-01-01"),
            ownedBackupName("2026-01-02"),
            ownedBackupName("2026-01-03")
        ]
        for (offset, name) in owned.enumerated() {
            try makeFile(named: name, in: tmp, creationDate: base.addingTimeInterval(TimeInterval(offset)))
        }
        // Foreign files created "now", i.e. newer than every owned file.
        let foreign = ["other.json", "backup-data.json"]
        for name in foreign {
            try makeFile(named: name, in: tmp)
        }

        let sut = makeSUT(maxBackupCount: 3)
        try sut.saveDestinationFolder(tmp)

        // Writing today's (new-day) backup triggers rotation.
        try sut.write(data: Data("today".utf8))

        // Foreign files are always untouched.
        for name in foreign {
            #expect(exists(name, in: tmp))
        }
        // Only the oldest *owned* backup is trimmed; the newer owned backups survive.
        #expect(!exists(owned[0], in: tmp), "The oldest owned backup should have been trimmed")
        #expect(exists(owned[1], in: tmp))
        #expect(exists(owned[2], in: tmp))
    }

    @Test("Listing backups returns only the app's own files")
    func listingReturnsOnlyOwnedFiles() throws {
        let tmp = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tmp) }

        let owned = [ownedBackupName("2026-01-01"), ownedBackupName("2026-02-15")]
        for name in owned {
            try makeFile(named: name, in: tmp)
        }
        for name in ["other_app.json", "data.json", "notes.txt"] {
            try makeFile(named: name, in: tmp)
        }
        // A directory whose name ends in ".json" must also be ignored.
        try FileManager.default.createDirectory(at: tmp.appendingPathComponent("subdir.json"),
                                                withIntermediateDirectories: true)

        let sut = makeSUT()
        try sut.saveDestinationFolder(tmp)

        let names = Set(try sut.getAllDocumentsData().map(\.name))

        #expect(names == Set(owned))
    }

    @Test("deleteAllBackupFiles removes only the app's own files")
    func deleteAllRemovesOnlyOwnedFiles() throws {
        let tmp = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tmp) }

        let owned = [ownedBackupName("2026-01-01"), ownedBackupName("2026-02-15")]
        for name in owned {
            try makeFile(named: name, in: tmp)
        }
        let foreign = ["other_app.json", "data.json", "notes.txt"]
        for name in foreign {
            try makeFile(named: name, in: tmp)
        }

        let sut = makeSUT()
        try sut.saveDestinationFolder(tmp)

        try sut.deleteAllBackupFiles()

        for name in owned {
            #expect(!exists(name, in: tmp), "Owned backup \(name) should have been deleted")
        }
        for name in foreign {
            #expect(exists(name, in: tmp), "Foreign file \(name) must never be deleted")
        }
    }

    @Test("delete(fileName:) refuses a file the app did not create")
    func deleteFileNameRefusesForeignFile() throws {
        let tmp = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tmp) }

        let foreignName = "other_app_secrets.json"
        try makeFile(named: foreignName, in: tmp)

        let sut = makeSUT()
        try sut.saveDestinationFolder(tmp)

        #expect(throws: AuthError.backup(.unrecognizedBackupFile)) {
            try sut.delete(fileName: foreignName)
        }
        #expect(exists(foreignName, in: tmp),
                "A foreign file must never be deleted via delete(fileName:)")
    }

    @Test("delete(fileName:) removes one of the app's own backups")
    func deleteFileNameRemovesOwnedFile() throws {
        let tmp = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tmp) }

        let ownedName = ownedBackupName("2026-01-01")
        try makeFile(named: ownedName, in: tmp)

        let sut = makeSUT()
        try sut.saveDestinationFolder(tmp)

        try sut.delete(fileName: ownedName)

        #expect(!exists(ownedName, in: tmp))
    }

    @Test("A freshly written backup follows the recognized naming convention")
    func writtenBackupIsRecognizedAsOwned() throws {
        let tmp = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tmp) }

        // A pre-existing foreign file must not appear in the listing after we write our backup.
        try makeFile(named: "unrelated.json", in: tmp)

        let sut = makeSUT()
        try sut.saveDestinationFolder(tmp)

        try sut.write(data: Data("backup".utf8))

        let listed = try sut.getAllDocumentsData()
        #expect(listed.count == 1)
        let name = try #require(listed.first?.name)
        #expect(name.hasPrefix("Proton_Authenticator_backup_"))
        #expect(name.hasSuffix(".json"))
    }
}
