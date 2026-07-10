//
// BackUpManager.swift
// Proton Authenticator - Created on 18/07/2025.
// Copyright (c) 2025 Proton Technologies AG
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
import Foundation
import Macro
import Models
import UIKit

@MainActor
public protocol BackUpServicing: Sendable {
    var destinationFolderURL: URL? { get }

    func write(data: Data) throws
    func read(fileName: String) throws -> Data
    func getAllDocumentsData() throws -> [BackUpFileInfo]
    func delete(fileName: String) throws
    func deleteAllBackupFiles() throws
    func saveDestinationFolder(_ url: URL) throws
    func clearDestinationFolder()
}

public struct BackUpFileInfo: Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let creationDate: Date
    public let url: URL

    init(id: String = UUID().uuidString, name: String, creationDate: Date, url: URL) {
        self.id = id
        self.name = name
        self.creationDate = creationDate
        self.url = url
    }

    public var displayedDate: String {
        creationDate.formattedBackupDate
    }
}

@MainActor
public final class BackUpManager: BackUpServicing {
    private let coordinator: NSFileCoordinator
    private let maxBackupCount: Int
    private let dateFormatter: DateFormatter
    private let keychainService: any KeychainServicing
    private let settingsService: any SettingsServicing
    private let logger: any LoggerProtocol
    private var documentURL: URL?
    private static let backupFileNamePrefix = "Proton_Authenticator_backup_"

    public var destinationFolderURL: URL? {
        documentURL
    }

    public init(maxBackupCount: Int = 5,
                keychainService: any KeychainServicing,
                settingsService: any SettingsServicing,
                logger: any LoggerProtocol) {
        coordinator = NSFileCoordinator()
        self.maxBackupCount = maxBackupCount
        self.keychainService = keychainService
        self.settingsService = settingsService
        self.logger = logger
        dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.dateFormat = "yyyy-MM-dd"
        restoreDestinationFolder()
    }

    /// Creates a security-scoped bookmark for `url`, persists it to the Keychain, and enables folder
    /// backup. The caller must hold security-scoped access to `url` (the document picker provides it).
    public func saveDestinationFolder(_ url: URL) throws {
        let bookmarkOptions: URL.BookmarkCreationOptions = ProcessInfo.processInfo.isiOSAppOnMac
            ? .macSecurityScope
            : .minimalBookmark
        let bookmarkData = try url.bookmarkData(options: bookmarkOptions,
                                                includingResourceValuesForKeys: nil,
                                                relativeTo: nil)
        try keychainService.set(bookmarkData,
                                for: AppConstants.Settings.backupFolderBookmark,
                                shouldSync: false)
        documentURL = url
        settingsService.toggleFolderBackup(true)
    }

    public func clearDestinationFolder() {
        settingsService.toggleFolderBackup(false)
        try? keychainService.delete(keyId: AppConstants.Settings.backupFolderBookmark, isSynced: false)
        documentURL = nil
    }

    public func write(data: Data) throws {
        guard let documentURL else {
            throw AuthError.backup(.noDestinationFolder)
        }

        try documentURL.withSecurityScopedAccess { url in
            let todayFileName = getTodaysBackupFileName()
            let targetURL = url.appendingPathComponent(todayFileName)

            if FileManager.default.fileExists(atPath: targetURL.path) {
                try coordinatedWrite(at: targetURL) { url in
                    try data.write(to: url, options: .atomic)
                }
            } else {
                try enforceFileRotationPolicy()
                try coordinatedWrite(at: targetURL) { url in
                    try data.write(to: url, options: .atomic)
                }
            }
        }
    }

    public func read(fileName: String) throws -> Data {
        guard let documentURL else {
            throw AuthError.backup(.noDestinationFolder)
        }

        return try documentURL.withSecurityScopedAccess { url in
            let targetURL = url.appendingPathComponent(fileName)
            var coordinationError: NSError?
            var data: Data?
            var readError: Error?

            coordinator.coordinate(readingItemAt: targetURL, options: [], error: &coordinationError) { url in
                do {
                    data = try Data(contentsOf: url)
                } catch {
                    readError = error
                }
            }

            if let error = readError {
                throw error
            }

            if let coordinationError {
                throw coordinationError
            }

            guard let data else {
                throw AuthError.backup(.noData)
            }

            return data
        }
    }

    public func deleteAllBackupFiles() throws {
        guard let documentURL else {
            return
        }

        try documentURL.withSecurityScopedAccess { url in
            let fileURLs = try FileManager.default.contentsOfDirectory(at: url,
                                                                       includingPropertiesForKeys: nil,
                                                                       options: [])
            // Only ever delete files this app created; never touch other apps' files that may
            // live in the same user-chosen folder.
            for fileURL in fileURLs where Self.isOwnedBackupFileName(fileURL.lastPathComponent) {
                try FileManager.default.removeItem(at: fileURL)
            }
        }
    }

    public func getAllDocumentsData() throws -> [BackUpFileInfo] {
        guard let documentURL else {
            throw AuthError.backup(.noDestinationFolder)
        }

        return try documentURL.withSecurityScopedAccess { _ in
            try getAllFilesWithMetadata().sorted { $0.creationDate > $1.creationDate }
        }
    }

    public func delete(fileName: String) throws {
        guard let documentURL else {
            throw AuthError.backup(.noDestinationFolder)
        }

        // Defense in depth: refuse to delete anything that isn't one of our own backup files,
        // even if a caller passes an arbitrary name from outside this manager.
        guard Self.isOwnedBackupFileName(fileName) else {
            throw AuthError.backup(.unrecognizedBackupFile)
        }

        try documentURL.withSecurityScopedAccess { url in
            let targetURL = url.appendingPathComponent(fileName)
            try coordinatedDelete(at: targetURL)
        }
    }
}

private extension BackUpManager {
    /// Restores `documentURL` from the persisted security-scoped bookmark so that auto-backups
    /// triggered at cold launch (entry load, sync changes, mutations) can succeed without the user
    /// first visiting the BackUp screen. Disables folder backup if the bookmark is missing or stale.
    func restoreDestinationFolder() {
        guard settingsService.folderBackup else { return }

        // Migration: move bookmark from UserDefaults to Keychain on first launch after upgrade.
        if let legacyData = settingsService.backupFolderBookmark {
            try? keychainService.set(legacyData,
                                     for: AppConstants.Settings.backupFolderBookmark,
                                     shouldSync: false)
            settingsService.setBackupFolderBookmark(nil)
        }

        do {
            let bookmarkData: Data =
                try keychainService.get(keyId: AppConstants.Settings.backupFolderBookmark,
                                        isSynced: false)
            var isStale = false
            let url = try URL(resolvingBookmarkData: bookmarkData,
                              options: ProcessInfo.processInfo.isiOSAppOnMac ? .macSecurityScope : [],
                              relativeTo: nil,
                              bookmarkDataIsStale: &isStale)
            if isStale {
                throw AuthError.backup(.staleBookmark)
            }
            documentURL = url
        } catch {
            log(.error, "Failed to restore backup destination folder: \(error.localizedDescription)")
            settingsService.toggleFolderBackup(false)
        }
    }

    func log(_ level: LogLevel, _ message: String, function: String = #function, line: Int = #line) {
        logger.log(level, category: .data, message, function: function, line: line)
    }

    /// True only for files this app created — `Proton_Authenticator_backup_<date>.json`.
    /// The app-specific prefix is the ownership signal; the `.json` extension is a secondary guard.
    static func isOwnedBackupFileName(_ fileName: String) -> Bool {
        fileName.hasPrefix(backupFileNamePrefix) && fileName.lowercased().hasSuffix(".json")
    }

    func getTodaysBackupFileName() -> String {
        let todayString = dateFormatter.string(from: Date())
        return "\(Self.backupFileNamePrefix)\(todayString).json"
    }

    func enforceFileRotationPolicy() throws {
        let files = try getAllFilesWithMetadata().sorted { $0.creationDate < $1.creationDate }

        guard files.count >= maxBackupCount else {
            return
        }

        let filesToDelete = files.count - maxBackupCount + 1

        for index in 0..<filesToDelete {
            try coordinatedDelete(at: files[index].url)
        }
    }

    func getAllFilesWithMetadata() throws -> [BackUpFileInfo] {
        guard let documentURL else {
            throw AuthError.backup(.noDestinationFolder)
        }

        let fileURLs = try FileManager.default.contentsOfDirectory(at: documentURL,
                                                                   includingPropertiesForKeys: [
                                                                       .creationDateKey,
                                                                       .isDirectoryKey
                                                                   ],
                                                                   options: .skipsHiddenFiles)

        return try fileURLs.compactMap { url -> BackUpFileInfo? in
            // Only recognise files this app created; ignore everything else in the folder.
            guard Self.isOwnedBackupFileName(url.lastPathComponent) else {
                return nil
            }

            let resourceValues = try url.resourceValues(forKeys: [
                .isDirectoryKey,
                .creationDateKey,
                .contentModificationDateKey
            ])
            guard let isDirectory = resourceValues.isDirectory,
                  !isDirectory,
                  let creationDate = resourceValues.creationDate
                  ?? resourceValues.contentModificationDate else {
                return nil
            }
            return BackUpFileInfo(name: url.lastPathComponent, creationDate: creationDate, url: url)
        }
    }

    func coordinatedDelete(at url: URL) throws {
        var coordinationError: NSError?
        var operationError: Error?

        coordinator
            .coordinate(writingItemAt: url, options: [.forDeleting], error: &coordinationError) { coordinatedURL in
                do {
                    try FileManager.default.removeItem(at: coordinatedURL)
                } catch {
                    operationError = error
                }
            }

        if let error = operationError {
            throw error
        }

        if let coordinationError {
            throw coordinationError
        }
    }

    func coordinatedWrite(at url: URL, block: (URL) throws -> Void) throws {
        var coordinationError: NSError?
        var operationError: Error?

        coordinator
            .coordinate(writingItemAt: url,
                        options: [.forReplacing],
                        error: &coordinationError) { coordinatedURL in
                do {
                    try block(coordinatedURL)
                } catch {
                    operationError = error
                }
            }

        if let error = operationError {
            throw error
        }

        if let coordinationError {
            throw coordinationError
        }
    }
}

private extension Date {
    var formattedBackupDate: String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        if calendar.isDateInToday(self) || calendar.isDateInYesterday(self) {
            return formatter.relativeFormatter.string(from: self)
        }
        if calendar.isDate(self, equalTo: Date(), toGranularity: .year) {
            return formatter.sameYearFormatter.string(from: self)
        }
        return formatter.otherYearFormatter.string(from: self)
    }
}

private extension DateFormatter {
    var relativeFormatter: DateFormatter {
        doesRelativeDateFormatting = true
        dateStyle = .short
        timeStyle = .short
        return self
    }

    var sameYearFormatter: DateFormatter {
        setLocalizedDateFormatFromTemplate("MMM d, HH:mm")
        return self
    }

    var otherYearFormatter: DateFormatter {
        setLocalizedDateFormatFromTemplate("MMM d yyyy, HH:mm")
        return self
    }
}
