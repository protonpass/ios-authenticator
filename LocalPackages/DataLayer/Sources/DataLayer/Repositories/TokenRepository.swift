//
// TokenRepository.swift
// Proton Authenticator - Created on 11/02/2025.
// Copyright (c) 2025 Proton Technologies AG
//
// This file is part of Proton Pass.
//
// Proton Pass is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Proton Pass is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Proton Pass. If not, see https://www.gnu.org/licenses/.

import AuthenticatorRustCore
import Foundation
import Models

public protocol TokenRepositoryProtocol {
    func entry(for uri: String) throws -> Token
    func export(entries: [Token]) throws -> String

    func deserialize(serializedData: [Data]) throws -> [Token]

    func generateCodes(entries: [Token], time: TimeInterval) throws -> [Code]

    func createSteamEntry(params: SteamParams) throws -> Token

    func createTotpEntry(params: TotpParams) throws -> Token

    func serialize(entries: [Token]) throws -> [Data]
}

public extension TokenRepositoryProtocol {
    func generateCodes(entries: [Token]) throws -> [Code] {
        try generateCodes(entries: entries, time: Date().timeIntervalSince1970)
    }
}

public final class TokenRepository: Sendable, TokenRepositoryProtocol {
    private let authenticatorRustClient: AuthenticatorMobileClient

    public init(authenticatorRustClient: AuthenticatorMobileClient = AuthenticatorMobileClient()) {
        self.authenticatorRustClient = authenticatorRustClient
    }

    public func entry(for uri: String) throws -> Token {
        try authenticatorRustClient.entryFromUri(uri: uri).toToken
    }

    public func export(entries: [Token]) throws -> String {
        try authenticatorRustClient.exportEntries(entries: entries.toAuthenticatorEntries)
    }

    public func deserialize(serializedData: [Data]) throws -> [Token] {
        try authenticatorRustClient.deserializeEntries(serialized: serializedData).toTokens
    }

    public func generateCodes(entries: [Token],
                              time: TimeInterval = Date().timeIntervalSince1970) throws -> [Code] {
        try authenticatorRustClient.generateCodes(entries: entries.toAuthenticatorEntries, time: UInt64(time))
            .toCodes
    }

    public func createSteamEntry(params: SteamParams) throws -> Token {
        try authenticatorRustClient
            .newSteamEntryFromParams(params: params.toAuthenticatorEntrySteamCreateParameters).toToken
    }

    public func createTotpEntry(params: TotpParams) throws -> Token {
        try authenticatorRustClient.newTotpEntryFromParams(params: params.toAuthenticatorEntryTotpCreateParameters)
            .toToken
    }

    public func serialize(entries: [Token]) throws -> [Data] {
        try authenticatorRustClient.serializeEntries(entries: entries.toAuthenticatorEntries)
    }
}
