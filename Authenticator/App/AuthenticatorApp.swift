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

    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #elseif os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif

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
            if viewModel.onboarded {
                EntriesView()
                    .accessibilityHidden(viewModel.showEntries)
                    .preferredColorScheme(viewModel.theme.preferredColorScheme)
                    .onOpenURL { url in
                        viewModel.handleDeepLink(url)
                    }
            } else {
                EmptyView()
                    .fullScreenMainBackground()
            }
        }
        .task {
            await viewModel.setUpFirstRun()
        }
        .adaptiveSheet(isPresented: .constant(!viewModel.onboarded),
                       isFullScreen: AppConstants.isPhone) {
            OnboardingView()
                .interactiveDismissDisabled()
                .sheetAlertService()
        }
        .animation(.default, value: viewModel.onboarded)
        .animation(.default, value: viewModel.showEntries)
        .onAppear {
            viewModel.updateWindowUserInterfaceStyle()
            viewModel.setWindowTintColor()
            if !viewModel.manualUnlock, !viewModel.showEntries {
                viewModel.toggleCover(shouldCover: true)
                viewModel.checkBiometrics()
            }
        }
        .onDisappear {
            viewModel.resetBiometricCheck()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                if !viewModel.manualUnlock, !viewModel.showEntries {
                    viewModel.checkBiometrics()
                }

            case .background, .inactive:
                viewModel.resetBiometricCheck()

            default:
                break
            }
        }
        .onChange(of: viewModel.showEntries) { _, newValue in
            viewModel.toggleCover(shouldCover: !newValue)
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
    private var isCheckingBiometric = false

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
    private(set) var setUpFirstRun

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
        guard !appSettings.isFirstRun, authenticationService.biometricEnabled else { return }
        Task { [weak self] in
            guard let self else { return }
            if isCheckingBiometric {
                return
            } else {
                isCheckingBiometric = true
            }
            defer { isCheckingBiometric = false }
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

    func toggleCover(shouldCover: Bool) {
        #if canImport(UIKit)
        guard let window = getFirstWindow() else { return }
        let tag = 1_912 // Just a random static tag
        if shouldCover {
            let vc = UIHostingController(rootView: BioLockView(manualUnlock: manualUnlock || !onboarded,
                                                               onUnlock: checkBiometrics))
            let view = vc.view ?? .init()
            view.translatesAutoresizingMaskIntoConstraints = false
            view.tag = tag
            window.addSubview(view)
            NSLayoutConstraint.activate([
                view.topAnchor.constraint(equalTo: window.topAnchor),
                view.leadingAnchor.constraint(equalTo: window.leadingAnchor),
                view.bottomAnchor.constraint(equalTo: window.bottomAnchor),
                view.trailingAnchor.constraint(equalTo: window.trailingAnchor)
            ])
        } else {
            getFirstWindow()?.subviews.first(where: { $0.tag == tag })?.removeFromSuperview()
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
