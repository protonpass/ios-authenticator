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
#if canImport(UIKit)
import UIKit
#endif

public nonisolated(unsafe) let kSharedUserDefaults: UserDefaults = {
    if let userDefaults = UserDefaults(suiteName: AppConstants.accessGroup) {
        return userDefaults
    } else {
        assertionFailure("Shared UserDefaults could not be initialized. Verify app group set up.")
        return .standard
    }
}()

public enum AppConstants {
    public static let teamId = "2SB5Z68H26"
    public static let service = "me.proton.authenticator"
    public static let accessGroup = "group.me.proton.authenticator"
    public static let keychainGroup = "\(teamId).\(accessGroup)"
    public static let appStoreUrl = "itms-apps://itunes.apple.com/app/id6741758667"

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
        public static let displayICloudBackUp = "DisplayICloudBackUp"
        public static let displayBESync = "DisplayBESync"
        public static let remoteActiveEncryptionKeyId = "RemoteActiveEncryptionKeyId"
    }

    @MainActor
    public static var isPhone: Bool {
        #if canImport(UIKit)
        UIDevice.current.userInterfaceIdiom == .phone
        #else
        false
        #endif
    }

    // periphery:ignore
    @MainActor
    public static var isIpad: Bool {
        #if canImport(UIKit)
        UIDevice.current.userInterfaceIdiom == .pad
        #else
        false
        #endif
    }

    // periphery:ignore
    @MainActor
    public static var isModile: Bool {
        #if canImport(UIKit)
        true
        #else
        false
        #endif
    }

    public static var isQaBuild: Bool {
        Bundle.main.isQaBuild
    }

    public enum EntryOptions {
        public static let supportedDigits: [Int] = [6, 8]
        public static let supportedPeriod: [Int] = [30, 60]
    }

    public enum CommonUrls {
        public static let feedbackUrl = "https://proton.me/support/contact"
    }

    public enum ContentFormatVersion {
        public static let entry = 1
        public static let key = 1
    }
}
