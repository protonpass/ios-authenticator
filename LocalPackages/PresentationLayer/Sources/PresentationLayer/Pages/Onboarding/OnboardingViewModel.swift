//
// OnboardingViewModel.swift
// Proton Authenticator - Created on 19/03/2025.
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

import CommonUtilities
import DataLayer
import FactoryKit
import Foundation
import Macro
import Models
import SwiftUI

enum OnboardStep: Sendable {
    case intro, `import`, biometric(BiometricType), iCloudSync
}

@MainActor
@Observable
final class OnboardingViewModel {
    private(set) var currentStep: OnboardStep = .intro
    private(set) var biometricEnabled = false
    private(set) var iCloudSyncEnabled = false

    @ObservationIgnored
    private var supportedBiometric: BiometricType?

    @ObservationIgnored
    @LazyInjected(\UseCaseContainer.getBiometricStatus)
    private var getBiometricStatus

    @ObservationIgnored
    @LazyInjected(\UseCaseContainer.authenticateBiometrically)
    private var authenticateBiometrically

    @ObservationIgnored
    @LazyInjected(\ToolsContainer.laContext)
    private var laContext

    @ObservationIgnored
    @LazyInjected(\ToolsContainer.logManager)
    private var logger

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.settingsService)
    private var appSettings

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.authenticationService)
    private var authenticationService

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.alertService)
    private var alertService

    @ObservationIgnored
    @LazyInjected(\UseCaseContainer.openAppSettings)
    private var openAppSettings

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.localDataManager) private var localDataManager

    @ObservationIgnored
    private var enablingBiometric = false

    init() {}

    func getSupportedBiometric() {
        switch getBiometricStatus(with: laContext) {
        case .notAvailable:
            logger.log(.warning, category: .ui, "Biometric not available")
        case let .available(biometric):
            supportedBiometric = biometric
        case let .error(error):
            handle(error.value)
        }
    }

    /// Return `true` if next step is available, `false` otherwise
    func goNext() -> Bool {
        switch currentStep {
        case .intro:
            currentStep = .import
        case .import:
            if let supportedBiometric {
                currentStep = .biometric(supportedBiometric)
            } else {
                return false
            }
        case .biometric:
            currentStep = .iCloudSync
        case .iCloudSync:
            return false
        }
        return true
    }

    func enableBiometric() {
        guard !enablingBiometric else { return }
        guard authenticationService.canUseBiometricAuthentication() else {
            let message: LocalizedStringKey =
                // swiftlint:disable:next line_length
                "To use biometric authentication, you need to enable Face ID/Touch ID for this app in your device settings."
            let alert = AlertDisplay.main(.init(title: "Enable biometrics",
                                                titleBundle: .module,
                                                message: .localized(message, .module),
                                                actions: [
                                                    .init(title: "Go to Settings",
                                                          titleBundle: .module,
                                                          action: { [weak self] in
                                                              guard let self else { return }
                                                              openAppSettings()
                                                          }),
                                                    .cancel
                                                ]))
            alertService.showAlert(alert)
            return
        }
        Task { [weak self] in
            guard let self else { return }
            defer { enablingBiometric = false }
            enablingBiometric = true
            do {
                let reason = #localized("Please authenticate", bundle: .module)
                if try await authenticateBiometrically(policy: AppConstants.laEnablingPolicy,
                                                       reason: reason) {
                    try authenticationService.setAuthenticationState(.active(authenticated: true))
                    biometricEnabled = true
                }
            } catch {
                handle(error)
            }
        }
    }

    func enableICloudSync() {
        appSettings.toggleICloudSync(true)
        iCloudSyncEnabled = true
        Task {
            await localDataManager.refreshLocalStorage()
        }
    }

    func handle(_ error: any Error, function: String = #function, line: Int = #line) {
        logger.log(.error, category: .ui, error.localizedDescription, function: function, line: line)
    }

    func finishOnboarding() {
        appSettings.setOnboarded(true)
    }
}
