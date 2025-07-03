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

import Combine
import CommonUtilities
import DataLayer
import DomainLayer
import FactoryKit
import Foundation
import Models
import PresentationLayer
import StoreKit
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
            mainContainer
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
}

private extension AuthenticatorApp {
    var mainContainer: some View {
        Group {
            if viewModel.showEntries {
                if viewModel.onboarded {
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
                    EmptyView()
                        .fullScreenMainBackground()
                }
            } else {
                BioLockView(manualUnlock: viewModel.manualUnlock,
                            onUnlock: viewModel.checkBiometrics)
            }
        }
        .adaptiveSheet(isPresented: .constant(!viewModel.onboarded),
                       isFullScreen: AppConstants.isPhone) {
            OnboardingView()
                .interactiveDismissDisabled()
        }
        .animation(.default, value: viewModel.onboarded)
        .animation(.default, value: viewModel.showEntries)
        .onAppear {
            viewModel.updateWindowUserInterfaceStyle()
            viewModel.setWindowTintColor()
            if !viewModel.manualUnlock, !viewModel.showEntries {
                viewModel.checkBiometrics()
            }
        }
        .onDisappear {
            viewModel.resetBiometricCheck()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                if !viewModel.manualUnlock, !viewModel.showEntries {
                    viewModel.checkBiometrics()
                }
            }
        }
        .mainAlertService()
    }
}

@Observable @MainActor
private final class AuthenticatorAppViewModel {
    var onboarded: Bool {
        appSettings.onboarded
    }

    var showEntries: Bool {
        switch authenticationService.currentState {
        case .inactive:
            true
        case let .active(authenticated: isChecked):
            isChecked
        }
    }

    var theme: Theme {
        appSettings.theme
    }

    @ObservationIgnored
    let manualUnlock = ProcessInfo().isiOSAppOnMac

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.deepLinkService)
    private var deepLinkService

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.alertService)
    private var alertService

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.settingsService)
    private var appSettings

    @ObservationIgnored
    @LazyInjected(\UseCaseContainer.updateAppAndRustVersion)
    private var updateAppAndRustVersion

    @ObservationIgnored
    @LazyInjected(\UseCaseContainer.setUpFirstRun)
    private var setUpFirstRun

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.authenticationService)
    private var authenticationService

    @ObservationIgnored
    @LazyInjected(\UseCaseContainer.setUpSentry)
    private var sentry

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.reviewService)
    private var reviewService

    @ObservationIgnored
    private var cancellables = Set<AnyCancellable>()

    init() {
        sentry()
        updateAppAndRustVersion(for: .main, userDefaults: .standard)
        setUpFirstRun()

        reviewService.askForReviewEventStream
            .receive(on: DispatchQueue.main)
            .sink { _ in
                #if os(iOS)
                // Only ask for reviews when not in macOS because macOS doesn't respect 3 times per year limit
                if !ProcessInfo.processInfo.isiOSAppOnMac,
                   let scene = UIApplication.shared
                   .connectedScenes
                   .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                    AppStore.requestReview(in: scene)
                }
                #endif
            }
            .store(in: &cancellables)
    }

    func handleDeepLink(_ url: URL) {
        Task { [weak self] in
            guard let self else { return }
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
        guard authenticationService.biometricEnabled else { return }
        Task { [weak self] in
            guard let self else { return }
            do {
                try await authenticationService.checkBiometrics()
            } catch {
                alertService.showError(error)
            }
        }
    }

    func setWindowTintColor() {
        #if canImport(UIKit)
        // Workaround confirmation dialogs and alerts buttons' tint color always being blue
        let window = getFirstWindow()
        window?.tintColor = AuthenticatorColor.UIColor.accent
        #endif
    }

    func updateWindowUserInterfaceStyle() {
        #if canImport(UIKit)
        // Workaround confirmation dialogs and alerts don't respect theme settings (always dark)
        let window = getFirstWindow()
        window?.overrideUserInterfaceStyle = switch appSettings.theme {
        case .dark: .dark
        case .light: .light
        case .system: .unspecified
        }
        #endif
    }
}

private extension AuthenticatorAppViewModel {
    #if canImport(UIKit)
    func getFirstWindow() -> UIWindow? {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            return window
        }
        return nil
    }
    #endif
}
