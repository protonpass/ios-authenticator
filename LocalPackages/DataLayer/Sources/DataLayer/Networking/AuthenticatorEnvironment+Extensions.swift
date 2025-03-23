//
// AuthenticatorEnvironment+Extensions.swift
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
import Models

extension AuthenticatorEnvironment {
    func parameters(bundle: Bundle = .module) -> Parameters {
        let constantDict = switch self {
        case .black: bundle.parse(plist: .black)
        case .prod: bundle.parse(plist: .prod)
        case .scientist: bundle.parse(plist: .scientist)
        }

        var signUpDomain = constantDict.value(for: .signupDomain)
        let captchaHost = constantDict.value(for: .captchaHost)
        let hvHost = constantDict.value(for: .humanVerificationHost)
        var accountHost = constantDict.value(for: .accountHost)
        var defaultHost = constantDict.value(for: .defaultHost)
        var apiHost = constantDict.value(for: .apiHost)
        let defaultPath = constantDict.value(for: .defaultPath)
        let sentryDns = constantDict.value(for: .sentryDsn)

        if case let .scientist(name) = self {
            let replace: (String) -> String = { value in
                value.replacingOccurrences(of: "<ENV_NAME>", with: name)
            }
            signUpDomain = replace(signUpDomain)
            accountHost = replace(accountHost)
            defaultHost = replace(defaultHost)
            apiHost = replace(apiHost)
        }

        return .init(signupDomain: signUpDomain,
                     captchaHost: captchaHost,
                     humanVerificationV3Host: hvHost,
                     accountHost: accountHost,
                     defaultHost: defaultHost,
                     apiHost: apiHost,
                     defaultPath: defaultPath,
                     sentryDns: sentryDns)
    }
}

private enum ConstantPlist: String {
    case black = "Constant-Black"
    case prod = "Constant-Prod"
    case scientist = "Constant-Scientist"

    enum Key: String {
        case signupDomain = "SIGNUP_DOMAIN"
        case captchaHost = "CAPTCHA_HOST"
        case humanVerificationHost = "HUMAN_VERIFICATION_HOST"
        case accountHost = "ACCOUNT_HOST"
        case defaultHost = "DEFAULT_HOST"
        case apiHost = "API_HOST"
        case defaultPath = "DEFAULT_PATH"
        case sentryDsn = "SENTRY_DSN"
    }
}

private extension Bundle {
    func parse(plist: ConstantPlist) -> [String: String] {
        let name = plist.rawValue
        guard let url = url(forResource: name, withExtension: "plist"),
              let data = try? Data(contentsOf: url)
        else {
            assertionFailure("\(name).plist not found")
            return [:]
        }

        guard let plist =
            try? PropertyListSerialization.propertyList(from: data,
                                                        options: [],
                                                        format: nil) as? [String: String] else {
            assertionFailure("Failed to parse \(name).plist")
            return [:]
        }
        return plist
    }
}

private extension [String: String] {
    func value(for key: ConstantPlist.Key) -> String {
        self[key.rawValue] ?? ""
    }
}
