//
//
// SetUpSentry.swift
// Proton Authenticator - Created on 18/04/2025.
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
import Models
import Sentry

public protocol SetUpSentryUseCase {
    func execute()
}

public extension SetUpSentryUseCase {
    func callAsFunction() {
        execute()
    }
}

public final class SetUpSentry: SetUpSentryUseCase {
    public init() {}

    public func execute() {
        SentrySDK.start { options in
            options.dsn = AuthenticatorEnvironment.prod.parameters.sentryDsn
            options.tracesSampleRate = 0.5
            if ProcessInfo.processInfo.environment["me.proton.Authenticator.SentryDebug"] == "1" {
                options.debug = true
                options.tracesSampleRate = 1.0
            }
            options.enableTimeToFullDisplayTracing = true

            options.enableAppHangTracking = false
            options.enableFileIOTracing = true
            options.enableCoreDataTracing = true
            // EXPERIMENTAL
            #if os(iOS)
            options.enablePreWarmedAppStartTracing = true
            options.attachScreenshot = true
            options.attachViewHierarchy = true
            options.enableMetricKit = true
            options.swiftAsyncStacktraces = true
            options.enableAutoPerformanceTracing = true
            options.enableUserInteractionTracing = true
            #endif
            options.configureProfiling = {
                $0.sessionSampleRate = 1
            }
        }
    }
}
