//
// AppConstants.swift
// Proton Authenticator - Created on 11/02/2025.
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

import Foundation
import LocalAuthentication

#if canImport(UIKit)
import UIKit
#endif

nonisolated(unsafe) public let kSharedUserDefaults: UserDefaults = {
    if let userDefaults = UserDefaults(suiteName: AppConstants.accessGroup) {
        return userDefaults
    } else {
        assertionFailure("Shared UserDefaults could not be initialized. Verify app group set up.")
        return .standard
    }
}()

public enum AppConstants: Sendable {
    public static let appID = "6741758667"
    public static let teamId = "2SB5Z68H26"
    public static let service = "me.proton.authenticator"
    public static let accessGroup = "group.me.proton.authenticator"
    public static let keychainGroup = "\(teamId).\(accessGroup)"
    public static let maxFileSizeInBytes = 10 * 1_024 * 1_024 // 10 MB
    public static let icloudContainerIdentifier = "iCloud.me.proton.authenticator"

    public enum AppStore {
        /// Used to open the app on App Store when force upgrading
        public static let appUrl = URL(string: "itms-apps://itunes.apple.com/app/id\(appID)")
        public static let reviewAppUrl =
            URL(string: "itms-apps://itunes.apple.com/app/id\(appID)?action=write-review")
        public static let referralUrl = URL(string: "https://apps.apple.com/app/id\(appID)")
    }

    public enum QA {
        public static let mockEntriesDisplay = "MockEntriesDisplay"
        public static let mockEntriesCount = "MockEntriesCount"
    }

    public enum Settings {
        public static let isFirstRun = "IsFirstRun"
        public static let searchBarMode = "SearchBarMode"
        public static let theme = "Theme"
        public static let displayCode = "DisplayCode"
        public static let digitStyle = "DigitStyle"
        public static let animateCode = "AnimateCode"
        public static let onboarded = "Onboarded"
        public static let showPassBanner = "ShowPassBanner"
        public static let authenticationState = "AuthenticationState"
        public static let hapticFeedbackEnabled = "HapticFeedbackEnabled"
        public static let focusSearchOnLaunchEnabled = "FocusSearchOnLaunchEnabled"
        public static let showFaviconsEnabled = "ShowFaviconsEnabled"
        public static let folderBackup = "FolderBackup"
        public static let iCloudSync = "ICloudBackUp"
        public static let remoteEncryptionKeyId = "RemoteEncryptionKeyId"
        public static let fullBackUp = "FullBackUp"
        public static let unsupportedScanning = "UnsupportedScanning"
        public static let backupPassword = "BackupPassword"
        public static let backupFolderBookmark = "BackupFolderBookmark"
        public static let lastBackupHash = "LastBackupHash"
        public static let sortOption = "SortOption"
        public static let lastCoreEventId = "LastCoreEventId"
        public static let iCloudDisablePromptDismissed = "ICloudDisablePromptDismissed"
    }

    public enum FileBackup {
        public static let backupFileNamePrefix = "Proton_Authenticator_backup_"
        public static let backupSubfolderName = "Proton Authenticator"
    }

    public enum NetworkSettings {
        public static let batchSize = 100
    }

    @MainActor
    public static var isPhone: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone
        #else
        false
        #endif
    }

    // periphery:ignore
    @MainActor
    public static var isIpad: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .pad
        #else
        false
        #endif
    }

    // periphery:ignore
    @MainActor
    public static var isMobile: Bool {
        #if canImport(UIKit)
        !ProcessInfo.processInfo.isiOSAppOnMac
        #else
        false
        #endif
    }

    public static var isIOS: Bool {
        #if os(iOS)
        true
        #else
        false
        #endif
    }

    /// We don't allow changing search bar position on macOS 26
    /// because custom bottom search bar doesn't look great with liquid glass design
    @MainActor
    public static var adjustableSearchBarPosition: Bool {
        if #available(iOS 26, macOS 26, *) {
            isPhone
        } else {
            true
        }
    }

    public static var isQaBuild: Bool {
        Bundle.main.isQaBuild
    }

    public enum EntryOptions {
        public static let supportedDigits: [Int] = [6, 7, 8]
        public static let supportedPeriod: [Int] = [30, 60]
    }

    public enum CommonUrls {
        public static let feedbackUrl = "https://proton.me/support/contact"
        public static let iCloudSyncInfos = "https://proton.me/support/keychain-issues-authenticator/"
    }

    public enum ContentFormatVersion {
        public static let entry = 1
        public static let key = 1
    }

    public static var laEnablingPolicy: LAPolicy {
        .deviceOwnerAuthentication
    }
}
