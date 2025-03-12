//
// Models+Extensions.swift
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
import Models

extension AuthenticatorEntryModel {
    var toEntry: Entry {
        Entry(name: name, uri: uri, period: Int(period), type: entryType.toType, note: note)
    }
}

extension [AuthenticatorEntryModel] {
    var toEntries: [Entry] {
        map(\.toEntry)
    }
}

extension AuthenticatorEntryType {
    var toType: TotpType {
        switch self {
        case .steam:
            .steam
        case .totp:
            .totp
        }
    }
}

extension [Entry] {
    var toRustEntries: [AuthenticatorEntryModel] {
        map(\.toRustEntry)
    }
}

extension Entry {
    var toRustEntry: AuthenticatorEntryModel {
        AuthenticatorEntryModel(name: name,
                                uri: uri,
                                period: UInt16(period),
                                note: note,
                                entryType: type.toAuthenticatorEntryType)
    }
}

extension TotpType {
    var toAuthenticatorEntryType: AuthenticatorEntryType {
        switch self {
        case .steam:
            .steam
        case .totp:
            .totp
        }
    }
}

extension [AuthenticatorCodeResponse] {
    var toCodes: [Code] {
        map(\.toCode)
    }
}

extension AuthenticatorCodeResponse {
    var toCode: Code {
        Code(current: currentCode, next: nextCode)
    }
}

extension SteamParams {
    var toRustParams: AuthenticatorEntrySteamCreateParameters {
        AuthenticatorEntrySteamCreateParameters(name: name, secret: secret, note: note)
    }
}

extension TotpParams {
    var toRustParams: AuthenticatorEntryTotpCreateParameters {
        let period: UInt16? = if let period {
            UInt16(period)
        } else {
            nil
        }
        let digits: UInt8? = if let digits {
            UInt8(digits)
        } else {
            nil
        }
        return AuthenticatorEntryTotpCreateParameters(name: name,
                                                      secret: secret,
                                                      issuer: issuer,
                                                      period: period,
                                                      digits: digits,
                                                      algorithm: algorithm?.toAuthenticatorTotpAlgorithm,
                                                      note: note)
    }
}

extension TotpAlgorithm {
    var toAuthenticatorTotpAlgorithm: AuthenticatorTotpAlgorithm {
        switch self {
        case .sha1:
            .sha1
        case .sha256:
            .sha256
        case .sha512:
            .sha512
        }
    }
}

extension AuthenticatorTotpAlgorithm {
    var toTotpAlgorithm: TotpAlgorithm {
        switch self {
        case .sha1:
            .sha1
        case .sha256:
            .sha256
        case .sha512:
            .sha512
        }
    }
}

// MARK: - Import

extension AuthenticatorImportResult {
    var toImportResult: ImportResult {
        ImportResult(entries: entries.toEntries, errors: errors.toImportErrors)
    }
}

extension AuthenticatorImportError {
    var toImportError: ImportError {
        ImportError(context: context, message: message)
    }
}

extension [AuthenticatorImportError] {
    var toImportErrors: [ImportError] {
        map(\.toImportError)
    }
}
