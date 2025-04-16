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
    var theme: Theme { get }
    var searchBarDisplayMode: SearchBarDisplayMode { get }
    var entryUIConfiguration: EntryCellConfiguration { get }
    var onboarded: Bool { get }
    var showPassBanner: Bool { get }

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

    public private(set) var searchBarDisplayMode: SearchBarDisplayMode
    public private(set) var theme: Theme
    public private(set) var entryUIConfiguration: EntryCellConfiguration
    public private(set) var onboarded: Bool
    public private(set) var showPassBanner: Bool

    public init(store: UserDefaults) {
        self.store = store
        theme = Theme(rawValue: store.integer(forKey: AppConstants.Settings.theme)) ?? .default
        searchBarDisplayMode = SearchBarDisplayMode(rawValue: store
            .integer(forKey: AppConstants.Settings.searchBarMode)) ??
            .bottom
        let digitStyle = DigitStyle(rawValue: store.integer(forKey: AppConstants.Settings.digitStyle)) ?? .plain
        let hideEntryCode: Bool = store.bool(forKey: AppConstants.Settings.displayCode)
        let animateCodeChange = store.bool(forKey: AppConstants.Settings.animateCode)
        entryUIConfiguration = .init(hideEntryCode: hideEntryCode,
                                     digitStyle: digitStyle,
                                     animateCodeChange: animateCodeChange)
        onboarded = store.bool(forKey: AppConstants.Settings.onboarded)
        showPassBanner = store.bool(forKey: AppConstants.Settings.showPassBanner)
    }
}

// MARK: - Setter

public extension SettingsService {
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
        guard entryUIConfiguration.hideEntryCode != value else {
            return
        }
        store.set(value, forKey: AppConstants.Settings.displayCode)
        entryUIConfiguration = .init(hideEntryCode: value,
                                     digitStyle: entryUIConfiguration.digitStyle,
                                     animateCodeChange: entryUIConfiguration.animateCodeChange)
    }

    func setDigitStyle(_ value: DigitStyle) {
        guard entryUIConfiguration.digitStyle != value else {
            return
        }
        store.set(value.rawValue, forKey: AppConstants.Settings.digitStyle)
        entryUIConfiguration = .init(hideEntryCode: entryUIConfiguration.hideEntryCode,
                                     digitStyle: value,
                                     animateCodeChange: entryUIConfiguration.animateCodeChange)
    }

    func setCodeAnimation(_ value: Bool) {
        guard entryUIConfiguration.animateCodeChange != value else {
            return
        }
        store.set(value, forKey: AppConstants.Settings.animateCode)
        entryUIConfiguration = .init(hideEntryCode: entryUIConfiguration.hideEntryCode,
                                     digitStyle: entryUIConfiguration.digitStyle,
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
