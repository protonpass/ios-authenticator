//
// EntryRepository.swift
// Proton Authenticator - Created on 11/02/2025.
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
import DomainProtocols
import Foundation
import Models

public final class EntryRepository: Sendable, EntryRepositoryProtocol {
    private let rustClient: AuthenticatorMobileClient

    public init(rustClient: AuthenticatorMobileClient = AuthenticatorMobileClient()) {
        self.rustClient = rustClient
    }

    public func entry(for uri: String) throws -> Entry {
        try rustClient.entryFromUri(uri: uri).toEntry
    }

    public func export(entries: [Entry]) throws -> String {
        try rustClient.exportEntries(entries: entries.toAuthenticatorEntries)
    }

    public func deserialize(serializedData: [Data]) throws -> [Entry] {
        try rustClient.deserializeEntries(serialized: serializedData).toEntries
    }

    public func generateCodes(entries: [Entry],
                              time: TimeInterval = Date().timeIntervalSince1970) throws -> [Code] {
        try rustClient.generateCodes(entries: entries.toAuthenticatorEntries, time: UInt64(time))
            .toCodes
    }

    public func createSteamEntry(params: SteamParams) throws -> Entry {
        try rustClient
            .newSteamEntryFromParams(params: params.toAuthenticatorEntrySteamCreateParameters).toEntry
    }

    public func createTotpEntry(params: TotpParams) throws -> Entry {
        try rustClient.newTotpEntryFromParams(params: params.toAuthenticatorEntryTotpCreateParameters)
            .toEntry
    }

    public func serialize(entries: [Entry]) throws -> [Data] {
        try rustClient.serializeEntries(entries: entries.toAuthenticatorEntries)
    }
    
    public func getTotpParams(entry: Entry) throws -> TotpParams {
        let params = try rustClient.getTotpParams(entry: entry.toAuthenticatorEntryModel)
        
        return TotpParams(name: entry.name,
                          secret: params.secret,
                          issuer: params.issuer,
                          period: Int(params.period),
                          digits: Int(params.digits),
                          algorithm: params.algorithm.toTotpAlgorithm,
                          note: entry.note)
    }
}
