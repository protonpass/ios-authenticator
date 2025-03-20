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

import Factory
import Foundation
import Models
import SwiftUI

enum OnboardStep: Sendable {
    case intro, `import`, biometric(BiometricType)
}

@Observable
final class OnboardingViewModel {
    private(set) var currentStep: OnboardStep = .intro

    @ObservationIgnored
    private var supportedBiometric: BiometricType?

    @ObservationIgnored
    @LazyInjected(\UseCaseContainer.getBiometricStatus)
    private var getBiometricStatus

    @ObservationIgnored
    @LazyInjected(\ToolsContainer.laContext)
    private var laContext

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

    func handle(_ error: any Error) {
        // swiftlint:disable:next todo
        // TODO: Log error
        print(error.localizedDescription)
    }
}
