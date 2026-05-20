//
// SettingsServiceTests.swift
// Proton Authenticator - Created on 19/05/2026.
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

import CommonUtilities
import DataLayer
import Foundation
import Testing

@MainActor
@Suite(.tags(.service))
struct SettingsServiceTests {
    private func makeStore() -> UserDefaults {
        let suiteName = "SettingsServiceTests.\(UUID().uuidString)"
        let store = UserDefaults(suiteName: suiteName)!
        store.removePersistentDomain(forName: suiteName)
        return store
    }

    @Test("iCloudDisablePromptDismissed defaults to false")
    func iCloudDisablePromptDismissed_defaultsToFalse() {
        let sut = SettingsService(store: makeStore())
        #expect(sut.iCloudDisablePromptDismissed == false)
    }

    @Test("Setting iCloudDisablePromptDismissed updates the in-memory value")
    func setICloudDisablePromptDismissed_updatesValue() {
        let sut = SettingsService(store: makeStore())
        sut.setICloudDisablePromptDismissed(true)
        #expect(sut.iCloudDisablePromptDismissed == true)
    }

    @Test("iCloudDisablePromptDismissed persists across SettingsService instances")
    func iCloudDisablePromptDismissed_persistsAcrossInstances() {
        let store = makeStore()
        let firstSut = SettingsService(store: store)
        firstSut.setICloudDisablePromptDismissed(true)

        let secondSut = SettingsService(store: store)
        #expect(secondSut.iCloudDisablePromptDismissed == true)
    }
}
