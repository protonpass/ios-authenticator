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

    func setFirstRun(_ value: Bool)
    func setTheme(_ value: Theme)
    func setSearchBarMode(_ value: SearchBarDisplayMode)
    func setHideEntryCode(_ value: Bool)
    func setDigitStyle(_ value: DigitStyle)
    func setCodeAnimation(_ value: Bool)
    func setOnboarded(_ value: Bool)
    func togglePassBanner(_ value: Bool)
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

    public init(store: UserDefaults) {
        self.store = store
        store.register(defaults: [AppConstants.Settings.isFirstRun: true])

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
    }
}

// MARK: - Setter

public extension SettingsService {
    func setFirstRun(_ value: Bool) {
        guard isFirstRun != value else { return }
        store.set(value, forKey: AppConstants.Settings.isFirstRun)
        isFirstRun = value
    }

    func setTheme(_ value: Theme) {
        guard theme != value else {
            return
        }
        store.set(value.rawValue, forKey: AppConstants.Settings.theme)
        theme = value
    }

    func setSearchBarMode(_ value: SearchBarDisplayMode) {
        guard searchBarDisplayMode != value else {
            return
        }
        store.set(value.rawValue, forKey: AppConstants.Settings.searchBarMode)
        searchBarDisplayMode = value
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
        guard value != onboarded else { return }
        store.set(value, forKey: AppConstants.Settings.onboarded)
        onboarded = value
    }

    func togglePassBanner(_ value: Bool) {
        guard value != showPassBanner else { return }
        store.set(value, forKey: AppConstants.Settings.showPassBanner)
        showPassBanner = value
    }
}

private extension UserDefaults {
    func value<T: IntegerDefaulting>(for key: String) -> T {
        T(rawValue: integer(forKey: key)) ?? .default
    }
}
