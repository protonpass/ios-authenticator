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
    func callAsFunction()
}

public struct SetUpSentry: SetUpSentryUseCase {
    private let bundle: Bundle
    private let doh: AuthDoH?

    public init(bundle: Bundle, doh: AuthDoH?) {
        self.bundle = bundle
        self.doh = doh
    }

    public func callAsFunction() {
        SentrySDK.start { options in
            options.dsn = AuthenticatorEnvironment.prod.parameters.sentryDsn
            options.tracesSampleRate = 0.5
            if ProcessInfo.processInfo.environment["me.proton.Authenticator.SentryDebug"] == "1" {
                options.debug = true
                options.tracesSampleRate = 1.0
            }
            if let doh {
                options.environment = doh.environment.name
            }
            options.releaseName = Bundle.main.fullAppVersionName
            options.enableTimeToFullDisplayTracing = true
            options.enableAppHangTracking = true
            options.enableWatchdogTerminationTracking = true
//            options.enableFileIOTracing = true
            options.enableCoreDataTracing = true
//            // EXPERIMENTAL
//            #if os(iOS)
//            options.enablePreWarmedAppStartTracing = true
//            options.enableMetricKit = true
//            options.swiftAsyncStacktraces = true
//
            if ProcessInfo.processInfo.isiOSAppOnMac {
                options.attachScreenshot = false
                options.attachViewHierarchy = false
                options.enableAutoPerformanceTracing = false
                options.enableUserInteractionTracing = false
                options.enableSwizzling = false
            }
//            else {
//                options.attachScreenshot = true
//                options.attachViewHierarchy = true
//                options.enableAutoPerformanceTracing = true
//                options.enableUserInteractionTracing = true
//            }
//            #endif
//            options.configureProfiling = {
//                $0.sessionSampleRate = 1
//            }
        }
    }
}

// SentrySDK.start { options in
//    options.dsn = bundle.plistString(for: .sentryDSN, in: .prod)
//    if ProcessInfo.processInfo.environment["me.proton.pass.SentryDebug"] == "1" {
//        options.debug = true
//    }
//    options.enableAppHangTracking = false
//    options.enableFileIOTracing = true
//    options.enableCoreDataTracing = true
//    options.attachViewHierarchy = true // EXPERIMENTAL
//    let environment = ProtonPassDoH(bundle: bundle).environment
//    options.environment = environment.name
//    options.enableCaptureFailedRequests = environment.isProd
// }
//
