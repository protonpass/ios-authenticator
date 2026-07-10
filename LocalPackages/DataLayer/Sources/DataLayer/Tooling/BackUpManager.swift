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
    private static let backupSubfolderName = "Proton Authenticator"

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

        try documentURL.withSecurityScopedAccess { parent in
            let directory = effectiveBackupDirectory(in: parent)
            let targetURL = directory.appendingPathComponent(getTodaysBackupFileName())

            if FileManager.default.fileExists(atPath: targetURL.path) {
                try coordinatedWrite(at: targetURL) { url in
                    try data.write(to: url, options: .atomic)
                }
            } else {
                try enforceFileRotationPolicy(in: directory)
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

        return try documentURL.withSecurityScopedAccess { parent in
            let targetURL = resolveExistingBackupURL(named: fileName, in: parent)
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

        try documentURL.withSecurityScopedAccess { parent in
            // Sweep both the dedicated subfolder and the picked-folder root (in case an earlier
            // migration was interrupted). Only ever delete files this app created — never other
            // apps' files that may live in the same user-chosen folder.
            let subfolder = parent.appendingPathComponent(Self.backupSubfolderName, isDirectory: true)
            for location in [subfolder, parent] {
                guard let fileURLs = try? FileManager.default.contentsOfDirectory(at: location,
                                                                                  includingPropertiesForKeys: nil,
                                                                                  options: [])
                else {
                    continue
                }
                for fileURL in fileURLs where Self.isOwnedBackupFileName(fileURL.lastPathComponent) {
                    try FileManager.default.removeItem(at: fileURL)
                }
            }
        }
    }

    public func getAllDocumentsData() throws -> [BackUpFileInfo] {
        guard let documentURL else {
            throw AuthError.backup(.noDestinationFolder)
        }

        return try documentURL.withSecurityScopedAccess { parent in
            let directory = effectiveBackupDirectory(in: parent)
            return try getAllFilesWithMetadata(in: directory).sorted { $0.creationDate > $1.creationDate }
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

        try documentURL.withSecurityScopedAccess { parent in
            let targetURL = resolveExistingBackupURL(named: fileName, in: parent)
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

    /// The directory backups actually live in: a dedicated subfolder of the user-picked folder, so
    /// every destructive operation runs in a directory that contains only our files. Creates the
    /// subfolder and migrates any legacy flat backups into it. Falls back to `parent` (the
    /// pre-subfolder behaviour) if the subfolder can't be created, so backups never fail.
    /// `parent` must already be security-scoped by the caller.
    func effectiveBackupDirectory(in parent: URL) -> URL {
        let subfolder = parent.appendingPathComponent(Self.backupSubfolderName, isDirectory: true)

        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: subfolder.path, isDirectory: &isDirectory)
        if exists, !isDirectory.boolValue {
            log(.error, "Backup subfolder path is occupied by a file; using the picked folder root")
            return parent
        }
        if !exists {
            do {
                try coordinatedCreateDirectory(at: subfolder)
            } catch {
                log(.error, "Failed to create backup subfolder: \(error.localizedDescription); using root")
                return parent
            }
        }
        migrateLegacyBackups(from: parent, to: subfolder)
        return subfolder
    }

    /// Moves backups written directly in `parent` by older app versions into `subfolder`. Only
    /// files this app created are moved — foreign files are never touched. Best-effort and
    /// idempotent (a no-op once the root holds no owned files).
    func migrateLegacyBackups(from parent: URL, to subfolder: URL) {
        guard let entries = try? FileManager.default.contentsOfDirectory(at: parent,
                                                                         includingPropertiesForKeys: nil,
                                                                         options: .skipsHiddenFiles)
        else {
            return
        }

        for source in entries where Self.isOwnedBackupFileName(source.lastPathComponent) {
            let destination = subfolder.appendingPathComponent(source.lastPathComponent)
            do {
                if FileManager.default.fileExists(atPath: destination.path) {
                    // The subfolder copy is authoritative; drop the redundant legacy duplicate.
                    try coordinatedDelete(at: source)
                } else {
                    try coordinatedMove(from: source, to: destination)
                }
            } catch {
                log(.error, "Failed to migrate \(source.lastPathComponent): \(error.localizedDescription)")
            }
        }
    }

    /// Resolves a backup file name to its URL inside the effective backup directory, falling back
    /// to the picked-folder root for the brief window before migration has run.
    func resolveExistingBackupURL(named fileName: String, in parent: URL) -> URL {
        let directory = effectiveBackupDirectory(in: parent)
        let candidate = directory.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: candidate.path) {
            return candidate
        }
        if directory != parent {
            let legacy = parent.appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: legacy.path) {
                return legacy
            }
        }
        return candidate
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

    func enforceFileRotationPolicy(in directory: URL) throws {
        let files = try getAllFilesWithMetadata(in: directory).sorted { $0.creationDate < $1.creationDate }

        guard files.count >= maxBackupCount else {
            return
        }

        let filesToDelete = files.count - maxBackupCount + 1

        for index in 0..<filesToDelete {
            try coordinatedDelete(at: files[index].url)
        }
    }

    func getAllFilesWithMetadata(in directory: URL) throws -> [BackUpFileInfo] {
        let fileURLs = try FileManager.default.contentsOfDirectory(at: directory,
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

    func coordinatedCreateDirectory(at url: URL) throws {
        var coordinationError: NSError?
        var operationError: Error?

        coordinator.coordinate(writingItemAt: url, options: [], error: &coordinationError) { coordinatedURL in
            do {
                try FileManager.default.createDirectory(at: coordinatedURL, withIntermediateDirectories: true)
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

    func coordinatedMove(from source: URL, to destination: URL) throws {
        var coordinationError: NSError?
        var operationError: Error?

        coordinator
            .coordinate(writingItemAt: source,
                        options: [.forMoving],
                        writingItemAt: destination,
                        options: [.forReplacing],
                        error: &coordinationError) { sourceURL, destinationURL in
                do {
                    try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
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
