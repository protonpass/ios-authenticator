//
//
// SettingsViewModel.swift
// Proton Authenticator - Created on 10/02/2025.
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

import Factory
import Foundation
import Macro
import Models
#if canImport(UIKit)
import UIKit
#endif

@Observable @MainActor
final class SettingsViewModel {
    private(set) var showPassBanner = true
    private(set) var backUpEnabled = false
    private(set) var syncEnabled = false
    private(set) var tapToRevealCodeEnabled = false
    private(set) var products: [ProtonProduct]
    private(set) var versionString: String?

    @ObservationIgnored
    private let bundle: Bundle

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.settingsService) private var settingsService

    var theme: Theme {
        settingsService.theme
    }

    var searchBarDisplay: SearchBarDisplayMode {
        settingsService.searchBarDisplayMode
    }

    var shouldHideCode: Bool {
        settingsService.entryUIConfiguration.hideEntryCode
    }

    var showNumberBackground: Bool {
        settingsService.entryUIConfiguration.displayNumberBackground
    }

    var isQaBuild: Bool {
        bundle.isQaBuild
    }

    init(bundle: Bundle = .main) {
        self.bundle = bundle
        products = ProtonProduct.allCases.filter { product in
            #if canImport(UIKit)
            if let url = URL(string: product.iOSAppUrl),
               UIApplication.shared.canOpenURL(url) {
                return false
            }
            #endif
            return true
        }
    }
}

extension SettingsViewModel {
    func setUp() async {
        versionString = #localized("Version %@", bundle.displayedAppVersion)
    }

    func togglePassBanner() {
        showPassBanner.toggle()
    }

    func toggleBackUp() {
        backUpEnabled.toggle()
    }

    func toggleSync() {
        syncEnabled.toggle()
    }

    func toggleTapToRevealCode() {
        tapToRevealCodeEnabled.toggle()
    }

    func toggleHideCode() {
        settingsService.setHideEntryCode(!shouldHideCode)
    }

    func toggleDisplayNumberBackground() {
        settingsService.setDisplayNumberBackground(!showNumberBackground)
    }

    func updateTheme(_ newValue: Theme) {
        guard newValue != settingsService.theme else { return }
        settingsService.setTheme(newValue)
    }

    func updateSearchBarDisplay(_ newValue: SearchBarDisplayMode) {
        guard newValue != settingsService.searchBarDisplayMode else { return }
        settingsService.setSearchBarMode(newValue)
    }
}
