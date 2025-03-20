//
// AuthenticateBiometrically.swift
// Proton Authenticator - Created on 18/02/2025.
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

import LocalAuthentication

public protocol AuthenticateBiometricallyUseCase: Sendable {
    func execute(policy: LAPolicy, reason: String) async throws -> Bool
}

public extension AuthenticateBiometricallyUseCase {
    func callAsFunction(policy: LAPolicy, reason: String) async throws -> Bool {
        try await execute(policy: policy, reason: reason)
    }
}

/**
 Do not create a class level `LAContext` or inject from the outside
 but create a new instance everytime we need to biometrically authenticate.
 Because once an instance of `LAContext` finishes evaluating, calling `evaluatePolicy`
 multiple times on a same `LAContext` always succeed without repeating authentication
 (maybe the result is cached but found no info in the docs)
 */
public final class AuthenticateBiometrically: AuthenticateBiometricallyUseCase {
    public init() {}

    public func execute(policy: LAPolicy, reason: String) async throws -> Bool {
        let context = LAContext()
        return try await context.evaluatePolicy(policy, localizedReason: reason)
    }
}
