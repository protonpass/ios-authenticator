//
// AuthenticatorEnvironment.swift
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

import Foundation

public enum AuthenticatorEnvironment: Sendable {
    case black, prod, scientist(String)

    public struct Parameters: Sendable {
        public let signupDomain: String
        public let captchaHost: String
        public let humanVerificationV3Host: String
        public let accountHost: String
        public let defaultHost: String
        public let apiHost: String
        public let defaultPath: String
        public let sentryDsn: String

        public init(signupDomain: String,
                    captchaHost: String,
                    humanVerificationV3Host: String,
                    accountHost: String,
                    defaultHost: String,
                    apiHost: String,
                    defaultPath: String,
                    sentryDsn: String) {
            self.signupDomain = signupDomain
            self.captchaHost = captchaHost
            self.humanVerificationV3Host = humanVerificationV3Host
            self.accountHost = accountHost
            self.defaultHost = defaultHost
            self.apiHost = apiHost
            self.defaultPath = defaultPath
            self.sentryDsn = sentryDsn
        }
    }
}
