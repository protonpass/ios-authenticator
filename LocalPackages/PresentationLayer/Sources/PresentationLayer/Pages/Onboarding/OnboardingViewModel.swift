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

import DataLayer
import Factory
import Foundation
import Macro
import Models
import SwiftUI

enum OnboardStep: Sendable {
    case intro, `import`, biometric(BiometricType)
}

@MainActor
@Observable
final class OnboardingViewModel {
    private(set) var currentStep: OnboardStep = .intro
    private(set) var biometricEnabled = false

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
    @LazyInjected(\ToolsContainer.laEnablingPolicy)
    private var laEnablingPolicy

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.settingsService)
    private var appSettings

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.authenticationService)
    private var authenticationService

    @ObservationIgnored
    private var enablingBiometric = false

    init() {}

    func getSupportedBiometric() {
        switch getBiometricStatus(with: laContext) {
        case .notAvailable:
            // swiftlint:disable:next todo
            // TODO: Add log here
            print("Biometric not available")

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
            return false
        }
        return true
    }

    func enableBiometric() {
        guard !enablingBiometric else { return }
        Task { [weak self] in
            guard let self else { return }
            defer { enablingBiometric = false }
            enablingBiometric = true
            do {
                if try await authenticateBiometrically(policy: laEnablingPolicy,
                                                       reason: #localized("Please authenticate")) {
                    try authenticationService.setAuthenticationState(.locked(isChecked: true))
                    biometricEnabled = true
                }
            } catch {
                handle(error)
            }
        }
    }

    func handle(_ error: any Error) {
        // swiftlint:disable:next todo
        // TODO: Log error
        print(error.localizedDescription)
    }

    func finishOnboarding() {
        appSettings.setOnboarded(true)
    }
}
