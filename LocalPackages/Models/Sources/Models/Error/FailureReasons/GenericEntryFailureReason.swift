//
// GenericEntryFailureReason.swift
// Proton Authenticator - Created on 18/02/2025.
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

public enum GenericEntryFailureReason: Sendable, CustomDebugStringConvertible {
    case missingGeneratedCodes(codeCount: Int, entryCount: Int)
    case missingEntryForGeneratedCode
    case wrongTypeOfEntryParams
    case duplicatedEntry
    case exportEmptyData
    case mainKeyNotFound
    case failedToRandomizeData
    case missingUserData
    case missingRemoteId

    public var debugDescription: String {
        switch self {
        case let .missingGeneratedCodes(codeCount, entryCount):
            String(localized: "Missing generated codes: \(codeCount) instead of \(entryCount)", bundle: .module)
        case .missingEntryForGeneratedCode:
            String(localized: "Missing entry for generated code", bundle: .module)
        case .wrongTypeOfEntryParams:
            String(localized: "Wrong type of entry params", bundle: .module)
        case .duplicatedEntry:
            String(localized: "An entry with the same data already exists", bundle: .module)
        case .exportEmptyData:
            String(localized: "No data to export", bundle: .module)
        case .mainKeyNotFound:
            String(localized: "Main key not found", bundle: .module)
        case .failedToRandomizeData:
            String(localized: "Failed to randomize data", bundle: .module)
        case .missingUserData:
            String(localized: "Missing user data", bundle: .module)
        case .missingRemoteId:
            String(localized: "Missing remote id for entity", bundle: .module)
        }
    }
}
