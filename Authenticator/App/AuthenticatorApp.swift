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
#if canImport(UIKit)
import UIKit
#endif

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
                            .onOpenURL { url in
                                viewModel.handleDeepLink(url)
                            }
                            .onChange(of: scenePhase) { _, newPhase in
                                if newPhase == .background {
                                    viewModel.resetBiometricCheck()
                                }
                            }
                    } else {
                        // swiftlint:disable:next todo
                        // TODO: fix issue if the user had set up faceid but uninstall the app we end up in a kinda of deadlock
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
            }
            .onAppear(perform: viewModel.updateWindowUserInterfaceStyle)
            .mainAlertService()
        }
        .onChange(of: viewModel.theme) { _, _ in
            viewModel.updateWindowUserInterfaceStyle()
        }
        #if os(macOS)
        .windowResizability(.contentMinSize)
        .windowToolbarStyle(.expanded)
        .windowStyle(.titleBar)
        .defaultSize(width: 800, height: 600)
        #endif

        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }

    var showEntriesView: Bool {
        switch viewModel.authenticationState {
        case .inactive:
            true
        case let .active(authenticated: isChecked):
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
        guard authenticationService.biometricEnabled else { return }
        do {
            try authenticationService.setAuthenticationState(.active(authenticated: false))
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

    func updateWindowUserInterfaceStyle() {
        #if canImport(UIKit)
        // Workaround confirmation dialogs and alerts don't respect theme settings (always dark)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.overrideUserInterfaceStyle = switch appSettings.theme {
            case .dark: .dark
            case .light: .light
            case .system: .unspecified
            }
        }
        #endif
    }
}
