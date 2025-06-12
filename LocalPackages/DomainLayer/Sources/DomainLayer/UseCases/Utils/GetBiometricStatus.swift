//
// GetBiometricStatus.swift
// Proton Authenticator - Created on 20/03/2025.
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

import CommonUtilities
import Foundation
import LocalAuthentication
import Models

public enum BiometricStatus: Sendable {
    case notAvailable
    case available(BiometricType)
    case error(BiometricError)
}

public enum BiometricError: Sendable {
    case laError(any Error, LAError.Code)
    case generic(any Error)

    public var value: any Error {
        switch self {
        case let .generic(error), let .laError(error, _):
            error
        }
    }
}

public protocol GetBiometricStatusUseCase: Sendable {
    func execute(with context: LAContext) -> BiometricStatus
}

public extension GetBiometricStatusUseCase {
    func callAsFunction(with context: LAContext) -> BiometricStatus {
        execute(with: context)
    }
}

public final class GetBiometricStatus: GetBiometricStatusUseCase {
    public init() {}

    public func execute(with context: LAContext) -> BiometricStatus {
        var error: NSError?

        if context.canEvaluatePolicy(AppConstants.laEnablingPolicy, error: &error) {
            return switch context.biometryType {
            case .none: .notAvailable
            case .faceID: .available(.faceID)
            case .touchID: .available(.touchID)
            case .opticID: .available(.opticID)
            @unknown default:
                .notAvailable
            }
        } else {
            if let error {
                return .error(handle(error))
            }
            return .notAvailable
        }
    }
}

private extension GetBiometricStatus {
    // swiftlint:disable:next cyclomatic_complexity
    func handle(_ error: NSError) -> BiometricError {
        switch error.code {
        case LAError.authenticationFailed.rawValue:
            .laError(error, .authenticationFailed)

        case LAError.userCancel.rawValue:
            .laError(error, .userCancel)

        case LAError.userFallback.rawValue:
            .laError(error, .userFallback)

        case LAError.systemCancel.rawValue:
            .laError(error, .systemCancel)

        case LAError.passcodeNotSet.rawValue:
            .laError(error, .passcodeNotSet)

        case LAError.appCancel.rawValue:
            .laError(error, .appCancel)

        case LAError.invalidContext.rawValue:
            .laError(error, .invalidContext)

        case LAError.biometryNotAvailable.rawValue:
            .laError(error, .biometryNotAvailable)

        case LAError.biometryNotEnrolled.rawValue:
            .laError(error, .biometryNotEnrolled)

        case LAError.biometryLockout.rawValue:
            .laError(error, .biometryLockout)

        case LAError.notInteractive.rawValue:
            .laError(error, .notInteractive)

        default:
            if #available(iOS 18, macOS 15, *),
               error.code == LAError.companionNotAvailable.rawValue {
                .laError(error, .companionNotAvailable)
            } else {
                .generic(error)
            }
        }
    }
}
