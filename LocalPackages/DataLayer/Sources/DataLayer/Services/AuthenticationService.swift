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
import Macro
import Models

public enum AuthenticationState: Sendable, Equatable, Hashable, Codable {
    case inactive
    case active(authenticated: Bool)
}

@MainActor
public protocol AuthenticationServicing: Sendable, Observable {
    var currentState: AuthenticationState { get }

    func setAuthenticationState(_ newState: AuthenticationState) throws
    func checkBiometrics() async throws
}

public extension AuthenticationServicing {
    var biometricEnabled: Bool {
        if case .active = currentState {
            true
        } else {
            false
        }
    }
}

@MainActor
@Observable
public final class AuthenticationService: AuthenticationServicing {
    @ObservationIgnored
    private let keychain: any KeychainServicing
    private let logger: any LoggerProtocol

    public private(set) var currentState: AuthenticationState = .inactive

    public init(keychain: any KeychainServicing,
                logger: any LoggerProtocol) {
        self.keychain = keychain
        self.logger = logger
        do {
            if let keychainValue: AuthenticationState = try keychain
                .get(key: AppConstants.Settings.authenticationState) {
                currentState = keychainValue
            }
        } catch KeychainError.invalidData {
            logger.log(.info, category: .data, "AuthenticationState not init. Use default value.")
        } catch {
            logger.log(.error, category: .data, error.localizedDescription)
        }
    }

    public func setAuthenticationState(_ newState: AuthenticationState) throws {
        guard currentState != newState else { return }

        try keychain.set(newState, for: AppConstants.Settings.authenticationState)
        currentState = newState
    }

    public func checkBiometrics() async throws {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = #localized("Please authenticate")
            do {
                let bioCheckValue = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                                                                     localizedReason: reason)
                currentState = .active(authenticated: bioCheckValue)
            } catch {
                currentState = .active(authenticated: false)
            }
        } else {
            guard let error else {
                return
            }
            throw error
        }
    }
}
