//
// AuthenticatorApp.swift
// Proton Authenticator - Created on 12/02/2025.
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

import DataLayer
import Factory
import Foundation
import Models
import PresentationLayer
import SwiftData
import SwiftUI

@main
struct AuthenticatorApp: App {
    @State private var viewModel = AuthenticatorAppViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if viewModel.onboarded {
                    if showEntriesView {
                        EntriesView()
                            .preferredColorScheme(viewModel.theme.preferredColorScheme)
                            .onOpenURL { url in
                                viewModel.handleDeepLink(url)
                            }
                            .onChange(of: scenePhase) { _, newPhase in
                                if newPhase == .background {
                                    viewModel.resetBiometricCheck()
                                }
                            }
                    } else {
                        BioLockView()
                            .onChange(of: scenePhase) { _, newPhase in
                                if newPhase == .active {
                                    viewModel.checkBiometrics()
                                }
                            }
                    }
                } else {
                    OnboardingView()
                }
            }.mainUIAlertService
        }
        #if os(macOS)
        .windowResizability(.contentMinSize)
        #endif
    }

    var showEntriesView: Bool {
        switch viewModel.authenticationState {
        case .unlocked:
            true
        case let .locked(isChecked: isChecked):
            isChecked
        }
    }
}

@Observable @MainActor
private final class AuthenticatorAppViewModel {
    var onboarded: Bool {
        appSettings.onboarded
    }

    var authenticationState: AuthenticationState {
        authenticationService.currentState
    }

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.deepLinkService)
    private var deepLinkService

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.alertService)
    var alertService

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.settingsService)
    private var appSettings

    @ObservationIgnored
    @LazyInjected(\UseCaseContainer.updateAppAndRustVersion)
    private var updateAppAndRustVersion
    @ObservationIgnored
    @LazyInjected(\ServiceContainer.authenticationService)
    private(set) var authenticationService

    var theme: Theme {
        appSettings.theme
    }

    init() {
        updateAppAndRustVersion(for: .main, userDefaults: .standard)
    }

    func handleDeepLink(_ url: URL) {
        Task {
            do {
                try await deepLinkService.handleDeeplink(url)
            } catch {
                alertService.showError(error)
            }
        }
    }

    func resetBiometricCheck() {
        do {
            try authenticationService.setAuthenticationState(.locked(isChecked: false))
        } catch {
            alertService.showError(error)
        }
    }

    func checkBiometrics() {
        Task {
            do {
                try await authenticationService.checkBiometrics()
            } catch {
                alertService.showError(error)
            }
        }
    }
}
