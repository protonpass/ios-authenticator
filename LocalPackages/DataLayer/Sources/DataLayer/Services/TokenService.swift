//
// TokenService.swift
// Proton Authenticator - Created on 17/02/2025.
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
import Foundation
import Models

public protocol CurrentDateProviderProtocol: Sendable {
    func getCurrentDate() -> Date
}

public final class CurrentDateProvider: CurrentDateProviderProtocol {
    public init() {}

    public func getCurrentDate() -> Date {
        .now
    }
}

public protocol TokenServiceProtocol: Sendable {
    func getToken(for entry: Entry) throws -> TokenUiModel
}

public final class TokenService: TokenServiceProtocol {
    private let rustClient: AuthenticatorMobileClient
    private let currentDateProvider: any CurrentDateProviderProtocol

    public init(rustClient: AuthenticatorMobileClient = .init(),
                currentDateProvider: any CurrentDateProviderProtocol = CurrentDateProvider()) {
        self.rustClient = rustClient
        self.currentDateProvider = currentDateProvider
    }
}

public extension TokenService {
    func getToken(for entry: Entry) throws -> TokenUiModel {
        let date = currentDateProvider.getCurrentDate()
        guard let code = try rustClient.generateCodes(entries: [entry.toAuthenticatorEntryModel],
                                                      time: UInt64(date.timeIntervalSince1970)).first else {
            throw AuthenticatorError.failedToCalculateToken(entry)
        }
        return .init(entry: entry, code: code.toCode, date: date)
    }
}
