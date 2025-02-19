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

public enum SettingUpdateEvent: Sendable {
    case searchBarMode(SearchBarMode)
    case theme(Theme)
}

public protocol SettingsServicing: Sendable {
    var updateEventStream: PassthroughSubject<SettingUpdateEvent, Never> { get }

    func getTheme() -> Theme
    func setTheme(_ value: Theme)

    func getSearchBarMode() -> SearchBarMode?
    func setSearchBarMode(_ value: SearchBarMode)

    // QA
    func getMockEntriesDisplay() -> Bool
    func setMockEntriesDisplay(_ value: Bool)

    func getMockEntriesCount() -> Int
    func setMockEntriesCount(_ value: Int)
}

public final class SettingsService: SettingsServicing {
    private nonisolated(unsafe) let store: UserDefaults

    public nonisolated(unsafe) let updateEventStream = PassthroughSubject<SettingUpdateEvent, Never>()

    public init(store: UserDefaults) {
        self.store = store
    }
}

public extension SettingsService {
    func getTheme() -> Theme {
        guard let rawValue = store.value(forKey: AppConstants.Settings.theme) as? Int else {
            return .default
        }
        return Theme(rawValue: rawValue) ?? .default
    }

    func setTheme(_ value: Theme) {
        store.set(value.rawValue, forKey: AppConstants.Settings.theme)
    }

    func getSearchBarMode() -> SearchBarMode? {
        guard let rawValue = store.value(forKey: AppConstants.Settings.searchBarMode) as? Int else {
            return nil
        }
        return SearchBarMode(rawValue: rawValue)
    }

    func setSearchBarMode(_ value: SearchBarMode) {
        store.set(value.rawValue, forKey: AppConstants.Settings.searchBarMode)
        updateEventStream.send(.searchBarMode(value))
    }

    func getMockEntriesDisplay() -> Bool {
        store.bool(forKey: AppConstants.QA.mockEntriesDisplay)
    }

    func setMockEntriesDisplay(_ value: Bool) {
        store.set(value, forKey: AppConstants.QA.mockEntriesDisplay)
    }

    func getMockEntriesCount() -> Int {
        store.integer(forKey: AppConstants.QA.mockEntriesCount)
    }

    func setMockEntriesCount(_ value: Int) {
        store.set(value, forKey: AppConstants.QA.mockEntriesCount)
    }
}
