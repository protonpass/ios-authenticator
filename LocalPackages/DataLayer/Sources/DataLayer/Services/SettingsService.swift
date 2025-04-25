//
// SettingsService.swift
// Proton Authenticator - Created on 19/02/2025.
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

import Combine
import CommonUtilities
import Foundation
import Models

@MainActor
public protocol SettingsServicing: Sendable, Observable {
    var isFirstRun: Bool { get }
    var theme: Theme { get }
    var searchBarDisplayMode: SearchBarDisplayMode { get }
    var entryCellConfiguration: EntryCellConfiguration { get }
    var onboarded: Bool { get }
    var showPassBanner: Bool { get }
    var hapticFeedbackEnabled: Bool { get }
    var focusSearchOnLaunch: Bool { get }

    func setFirstRun(_ value: Bool)
    func setTheme(_ value: Theme)
    func setSearchBarMode(_ value: SearchBarDisplayMode)
    func setHideEntryCode(_ value: Bool)
    func setDigitStyle(_ value: DigitStyle)
    func setCodeAnimation(_ value: Bool)
    func setOnboarded(_ value: Bool)
    func togglePassBanner(_ value: Bool)
    // periphery:ignore
    func toggleHapticFeedback(_ value: Bool)
    func toggleFocusSearchOnLaunch(_ value: Bool)
}

@MainActor
@Observable
public final class SettingsService: SettingsServicing {
    @ObservationIgnored
    private let store: UserDefaults

    public private(set) var isFirstRun: Bool
    public private(set) var searchBarDisplayMode: SearchBarDisplayMode
    public private(set) var theme: Theme
    public private(set) var entryCellConfiguration: EntryCellConfiguration
    public private(set) var onboarded: Bool
    public private(set) var showPassBanner: Bool
    public private(set) var hapticFeedbackEnabled: Bool
    public private(set) var focusSearchOnLaunch: Bool

    public init(store: UserDefaults) {
        self.store = store
        store.register(defaults: [
            AppConstants.Settings.isFirstRun: true,
            AppConstants.Settings.hapticFeedbackEnabled: true
        ])

        isFirstRun = store.bool(forKey: AppConstants.Settings.isFirstRun)
        theme = store.value(for: AppConstants.Settings.theme)
        searchBarDisplayMode = store.value(for: AppConstants.Settings.searchBarMode)
        let digitStyle: DigitStyle = store.value(for: AppConstants.Settings.digitStyle)
        let hideEntryCode = store.bool(forKey: AppConstants.Settings.displayCode)
        let animateCodeChange = store.bool(forKey: AppConstants.Settings.animateCode)
        entryCellConfiguration = .init(hideEntryCode: hideEntryCode,
                                       digitStyle: digitStyle,
                                       animateCodeChange: animateCodeChange)
        onboarded = store.bool(forKey: AppConstants.Settings.onboarded)
        showPassBanner = store.bool(forKey: AppConstants.Settings.showPassBanner)
        hapticFeedbackEnabled = store.bool(forKey: AppConstants.Settings.hapticFeedbackEnabled)
        focusSearchOnLaunch = store.bool(forKey: AppConstants.Settings.focusSearchOnLaunchEnabled)
    }
}

// MARK: - Setter

public extension SettingsService {
    func setFirstRun(_ value: Bool) {
        update(currentValue: &isFirstRun, newValue: value, key: AppConstants.Settings.isFirstRun)
    }

    func setTheme(_ value: Theme) {
        update(currentValue: &theme, newValue: value, key: AppConstants.Settings.theme)
    }

    func setSearchBarMode(_ value: SearchBarDisplayMode) {
        update(currentValue: &searchBarDisplayMode, newValue: value, key: AppConstants.Settings.searchBarMode)
    }

    func setHideEntryCode(_ value: Bool) {
        guard entryCellConfiguration.hideEntryCode != value else {
            return
        }
        store.set(value, forKey: AppConstants.Settings.displayCode)
        entryCellConfiguration = .init(hideEntryCode: value,
                                       digitStyle: entryCellConfiguration.digitStyle,
                                       animateCodeChange: entryCellConfiguration.animateCodeChange)
    }

    func setDigitStyle(_ value: DigitStyle) {
        guard entryCellConfiguration.digitStyle != value else {
            return
        }
        store.set(value.rawValue, forKey: AppConstants.Settings.digitStyle)
        entryCellConfiguration = .init(hideEntryCode: entryCellConfiguration.hideEntryCode,
                                       digitStyle: value,
                                       animateCodeChange: entryCellConfiguration.animateCodeChange)
    }

    func setCodeAnimation(_ value: Bool) {
        guard entryCellConfiguration.animateCodeChange != value else {
            return
        }
        store.set(value, forKey: AppConstants.Settings.animateCode)
        entryCellConfiguration = .init(hideEntryCode: entryCellConfiguration.hideEntryCode,
                                       digitStyle: entryCellConfiguration.digitStyle,
                                       animateCodeChange: value)
    }

    func setOnboarded(_ value: Bool) {
        update(currentValue: &onboarded, newValue: value, key: AppConstants.Settings.onboarded)
    }

    func togglePassBanner(_ value: Bool) {
        update(currentValue: &showPassBanner, newValue: value, key: AppConstants.Settings.showPassBanner)
    }

    func toggleHapticFeedback(_ value: Bool) {
        update(currentValue: &hapticFeedbackEnabled,
               newValue: value,
               key: AppConstants.Settings.hapticFeedbackEnabled)
    }

    func toggleFocusSearchOnLaunch(_ value: Bool) {
        update(currentValue: &focusSearchOnLaunch,
               newValue: value,
               key: AppConstants.Settings.focusSearchOnLaunchEnabled)
    }
}

private extension SettingsService {
    func update(currentValue: inout Bool, newValue: Bool, key: String) {
        guard newValue != currentValue else { return }
        store.set(newValue, forKey: key)
        currentValue = newValue
    }

    func update<T: IntegerDefaulting>(currentValue: inout T,
                                      newValue: T,
                                      key: String) {
        guard newValue.rawValue != currentValue.rawValue else { return }
        store.set(newValue.rawValue, forKey: key)
        currentValue = newValue
    }
}

private extension UserDefaults {
    func value<T: IntegerDefaulting>(for key: String) -> T {
        T(rawValue: integer(forKey: key)) ?? .default
    }
}
