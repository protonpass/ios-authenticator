//
// MockedSettingsService.swift
// Proton Authenticator - Created on 17/06/2025.
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
//

import DataLayer
import DomainLayer
import Foundation
import Models

final class MockedSettingsService: SettingsServicing {
    init() {}

    var isFirstRun = false
    var theme = Theme.system
    var searchBarDisplayMode = SearchBarDisplayMode.top
    var entryCellConfiguration = EntryCellConfiguration.default
    var onboarded = false
    var showPassBanner = false
    var hapticFeedbackEnabled = false
    var focusSearchOnLaunch = false
    var folderBackup = false
    var backupFolderBookmark: Data?
    var lastBackupHash: String?
    var iCloudSync = false
    var fullBackUp = false
    var unsupportedScanning = false
    var sortOption = SortOption.default
    var iCloudDisablePromptDismissed = false

    func setFirstRun(_ value: Bool) {
        isFirstRun = value
    }
    
    func setTheme(_ value: Theme) {
        theme = value
    }
    
    func setSearchBarMode(_ value: SearchBarDisplayMode) {
        searchBarDisplayMode = value
    }
    
    func setHideEntryCode(_ value: Bool) {
        entryCellConfiguration = .init(hideEntryCode: value,
                                       digitStyle: .boxed,
                                       animateCodeChange: .random())
    }
    
    func setDigitStyle(_ value: DigitStyle) {
        entryCellConfiguration = .init(hideEntryCode: false,
                                       digitStyle: value,
                                       animateCodeChange: .random())
    }
    
    func setCodeAnimation(_ value: Bool) {
        entryCellConfiguration = .init(hideEntryCode: false,
                                       digitStyle: .boxed,
                                       animateCodeChange: value)
    }
    
    func setOnboarded(_ value: Bool) {
        onboarded = value
    }
    
    func togglePassBanner(_ value: Bool) {
        showPassBanner = value
    }
    
    func toggleHapticFeedback(_ value: Bool) {
        hapticFeedbackEnabled = value
    }
    
    func toggleFocusSearchOnLaunch(_ value: Bool) {
        focusSearchOnLaunch = value
    }
    
    func toggleFolderBackup(_ value: Bool) {
        folderBackup = value
    }

    func setBackupFolderBookmark(_ data: Data?) {
        backupFolderBookmark = data
    }

    func setLastBackupHash(_ value: String?) {
        lastBackupHash = value
    }

    func toggleICloudSync(_ value: Bool) {
        iCloudSync = value
    }

    func setFullBackup(_ value: Bool) {
        fullBackUp = value
    }

    func setUnsupportedScanning(_ value: Bool) {
        unsupportedScanning = value
    }

    func setSortOption(_ value: SortOption) {
        sortOption = value
    }

    func setICloudDisablePromptDismissed(_ value: Bool) {
        iCloudDisablePromptDismissed = value
    }
}
