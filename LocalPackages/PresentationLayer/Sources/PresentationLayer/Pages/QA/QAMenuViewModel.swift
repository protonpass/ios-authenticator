//
// QAMenuViewModel.swift
// Proton Authenticator - Created on 18/02/2025.
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

import FactoryKit
import Foundation

@MainActor
@Observable
final class QAMenuViewModel {
    var onboarded: Bool {
        didSet {
            appSettings.setOnboarded(onboarded)
        }
    }

    var displayPassBanner: Bool {
        didSet {
            appSettings.togglePassBanner(displayPassBanner)
        }
    }

    @ObservationIgnored
    let allowedEntriesCount: [Int] = [5, 10, 20, 40, 80, 100, 200, 500]

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.qaService) var qaService

    @ObservationIgnored
    private let appSettings = resolve(\ServiceContainer.settingsService)

    init() {
        onboarded = appSettings.onboarded
        displayPassBanner = appSettings.showPassBanner
    }
}
