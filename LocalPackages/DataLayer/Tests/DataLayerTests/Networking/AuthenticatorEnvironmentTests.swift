//
// AuthenticatorEnvironmentTests.swift
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

#if DEBUG
@testable import DataLayer
#endif
import Models
import Testing

struct AuthenticatorEnvironmentTests {
    @Test
    func prodParameters() {
        let params = AuthenticatorEnvironment.prod.parameters
        #expect(params.sentryDsn == "https://e15338cd3f8140cea28c9f1abbcfe275@pass-api.proton.me/api/core/v4/reports/sentry/78")
        #expect(params.defaultPath.isEmpty)
        #expect(params.apiHost == "pass-api.proton.me")
        #expect(params.defaultHost == "https://pass-api.proton.me")
        #expect(params.accountHost == "https://account.proton.me")
        #expect(params.captchaHost == "https://pass-api.proton.me")
        #expect(params.humanVerificationV3Host == "https://verify.proton.me")
        #expect(params.signupDomain == "proton.me")
    }
}
