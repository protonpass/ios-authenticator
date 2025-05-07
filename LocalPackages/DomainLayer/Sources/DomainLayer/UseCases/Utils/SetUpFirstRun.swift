//
// SetUpFirstRun.swift
// Proton Authenticator - Created on 17/04/2025.
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

import DataLayer

@MainActor
public protocol SetUpFirstRunUseCase: Sendable {
    func execute()
}

public extension SetUpFirstRunUseCase {
    func callAsFunction() {
        execute()
    }
}

public final class SetUpFirstRun: SetUpFirstRunUseCase {
    let settingsService: any SettingsServicing
    let authenticationService: any AuthenticationServicing
    let logger: any LoggerProtocol

    public init(settingsService: any SettingsServicing,
                authenticationService: any AuthenticationServicing,
                logger: any LoggerProtocol) {
        self.settingsService = settingsService
        self.authenticationService = authenticationService
        self.logger = logger
    }

    public func execute() {
        log(.debug, "Setting up first run if applicable")
        guard settingsService.isFirstRun else {
            log(.debug, "Not the first run. Skipped set up.")
            return
        }

        defer { settingsService.setFirstRun(false) }
        do {
            try authenticationService.setAuthenticationState(.inactive)
            log(.info, "Finished setting up for first run")
        } catch {
            log(.error, "Failed to set up for first run \(error.localizedDescription)")
        }
    }
}

private extension SetUpFirstRun {
    func log(_ level: LogLevel, _ message: String, function: String = #function, line: Int = #line) {
        logger.log(level, category: .data, message, function: function, line: line)
    }
}
