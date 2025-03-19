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

    func setTheme(_ value: Theme)
    func setSearchBarMode(_ value: SearchBarDisplayMode)
    func setHideEntryCode(_ value: Bool)
    func setDisplayNumberBackground(_ value: Bool)
}

@MainActor
@Observable
public final class SettingsService: SettingsServicing {
    @ObservationIgnored
    private let store: UserDefaults

    public var searchBarDisplayMode: SearchBarDisplayMode
    public var theme: Theme
    public var entryUIConfiguration: EntryCellConfiguration

    public init(store: UserDefaults) {
        self.store = store
        theme = Theme(rawValue: store.integer(forKey: AppConstants.Settings.theme)) ?? .default
        searchBarDisplayMode = SearchBarDisplayMode(rawValue: store
            .integer(forKey: AppConstants.Settings.searchBarMode)) ??
            .bottom
        let displayNumberBackground: Bool = store.bool(forKey: AppConstants.Settings.numberBackground)
        let hideEntryCode: Bool = store.bool(forKey: AppConstants.Settings.displayCode)
        entryUIConfiguration = .init(hideEntryCode: hideEntryCode,
                                     displayNumberBackground: displayNumberBackground)
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
                                     displayNumberBackground: entryUIConfiguration.displayNumberBackground)
    }

    func setDisplayNumberBackground(_ value: Bool) {
        guard entryUIConfiguration.displayNumberBackground != value else {
            return
        }
        store.set(value, forKey: AppConstants.Settings.numberBackground)
        entryUIConfiguration = .init(hideEntryCode: entryUIConfiguration.hideEntryCode,
                                     displayNumberBackground: value)
    }
}
