//
// AuthenticationService.swift
// Proton Authenticator - Created on 23/03/2025.
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
import Foundation
import LocalAuthentication
import Models

@MainActor
public protocol AuthenticationServicing: Sendable, Observable {
    var biometricEnabled: Bool { get }
    var biometricChecked: Bool { get }

    func setBiometricEnabled(_ enabled: Bool) throws
    func checkBiometrics() async throws
    func resetBiometricValidation()
}

@MainActor
@Observable
public final class AuthenticationService: AuthenticationServicing {
    @ObservationIgnored
    private let keychain: any KeychainServicing

    public private(set) var biometricEnabled: Bool = false
    public private(set) var biometricChecked: Bool = false

    public init(keychain: any KeychainServicing = KeychainService(service: AppConstants.service,
                                                                  accessGroup: AppConstants.keychainGroup)) {
        self.keychain = keychain
        if let keychainValue: Bool = try? keychain.get(key: AppConstants.Settings.faceIdEnabled) {
            biometricEnabled = keychainValue
        }
    }

    public func setBiometricEnabled(_ enabled: Bool) throws {
        try keychain.set(enabled, for: AppConstants.Settings.faceIdEnabled)
        biometricEnabled = enabled
        biometricChecked = enabled
    }

    public func resetBiometricValidation() {
        biometricChecked = false
    }

    public func checkBiometrics() async throws {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Identify yourself!"
            biometricChecked = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                                                                localizedReason: reason)
        } else {
            guard let error else {
                return
            }
            throw error
        }
    }
}
