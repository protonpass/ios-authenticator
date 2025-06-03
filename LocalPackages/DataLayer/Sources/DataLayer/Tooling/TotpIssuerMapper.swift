//
// TotpIssuerMapper.swift
// Proton Authenticator - Created on 26/03/2025.
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

import AuthenticatorRustCore
import CommonUtilities
import Foundation
import Models
#if canImport(UIKit)
import UIKit
#endif

public protocol TOTPIssuerMapperServicing: Sendable {
    func lookup(issuer: String) -> AuthIssuerInfo?
}

/// A library to map TOTP issuer names to domains and icons
public final class TOTPIssuerMapper: TOTPIssuerMapperServicing {
    private let mapper: any AuthenticatorIssuerMapperProtocol
    private let cacheProtected: any MutexProtected<[String: AuthIssuerInfo]> = SafeMutex.create([:])

    public init(mapper: any AuthenticatorIssuerMapperProtocol = AuthenticatorIssuerMapper()) {
        self.mapper = mapper
    }

    /// Look up an issuer and return its domain and icon information
    /// - Parameter issuer: The issuer name from the TOTP
    /// - Returns: IssuerInfo containing the domain and icon name if available
    public func lookup(issuer: String) -> AuthIssuerInfo? {
        if let authIssuerInfo = cacheProtected.value[issuer] {
            return authIssuerInfo
        }

        let result = mapper.lookup(issuer: issuer)?.toAuthIssuerInfo
        if let result {
            cacheProtected.modify {
                $0[issuer] = result
            }
        }

        return result
    }
}

private extension IssuerInfo {
    var toAuthIssuerInfo: AuthIssuerInfo {
        // Randomising the host to be sure not to be rate limited
        let iconUrl = iconUrl
            .replacingOccurrences(of: "t0.gstatic.com",
                                  with: IconHostEndpoints.randomHost.rawValue)
        return AuthIssuerInfo(domain: domain, iconUrl: iconUrl)
    }
}

private enum IconHostEndpoints: String, CaseIterable, Equatable {
    case one = "t1.gstatic.com"
    case two = "t2.gstatic.com"
    case three = "t3.gstatic.com"

    static var randomHost: Self {
        allCases.randomElement() ?? .one
    }
}
