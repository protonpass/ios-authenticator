//
// RestoreBackUpDestinationFolder.swift
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
//

import CommonUtilities
import DataLayer
import Foundation

@MainActor
public protocol RestoreBackUpDestinationFolderUseCase: Sendable {
    @discardableResult
    func execute() -> URL?
}

public extension RestoreBackUpDestinationFolderUseCase {
    @MainActor
    @discardableResult
    func callAsFunction() -> URL? {
        execute()
    }
}

/// Restores `BackUpManager.documentURL` from the persisted security-scoped bookmark so that
/// auto-backups triggered at cold launch (entry load, sync changes, mutations) can succeed
/// without the user first visiting the BackUp screen.
@MainActor
public final class RestoreBackUpDestinationFolder: RestoreBackUpDestinationFolderUseCase {
    private let backUpManager: any BackUpServicing
    private let settingsService: any SettingsServicing
    private let keychainService: any KeychainServicing
    private let logger: any LoggerProtocol

    public init(backUpManager: any BackUpServicing,
                settingsService: any SettingsServicing,
                keychainService: any KeychainServicing,
                logger: any LoggerProtocol) {
        self.backUpManager = backUpManager
        self.settingsService = settingsService
        self.keychainService = keychainService
        self.logger = logger
    }

    @discardableResult
    public func execute() -> URL? {
        guard settingsService.folderBackup else { return nil }

        // Migration: move bookmark from UserDefaults to Keychain on first launch after upgrade
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
            return try backUpManager.resolveDestinationFolder(from: bookmarkData)
        } catch {
            log(.error, "Failed to restore backup destination folder: \(error.localizedDescription)")
            settingsService.toggleFolderBackup(false)
            return nil
        }
    }
}

private extension RestoreBackUpDestinationFolder {
    func log(_ level: LogLevel, _ message: String, function: String = #function, line: Int = #line) {
        logger.log(level, category: .data, message, function: function, line: line)
    }
}
