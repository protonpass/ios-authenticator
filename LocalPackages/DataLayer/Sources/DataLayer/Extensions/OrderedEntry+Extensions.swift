//
// OrderedEntry+Extensions.swift
// Proton Authenticator - Created on 28/05/2026.
// Copyright (c) 2026 Proton Technologies AG
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

import CryptoKit
import Foundation
import Models

extension OrderedEntry {
    func hashInto(_ hasher: inout SHA256) {
        hasher.appendLengthPrefixed(entry.id)
        hasher.appendLengthPrefixed(entry.name)
        hasher.appendLengthPrefixed(entry.uri)
        hasher.appendLengthPrefixed(entry.issuer)
        hasher.appendLengthPrefixed(entry.secret)
        hasher.appendLengthPrefixed(entry.note ?? "")
        hasher.appendLengthPrefixed(entry.type.rawValue)
        hasher.appendInt(entry.period)

        hasher.appendInt(revision)
        hasher.appendInt(flags)
        hasher.appendInt(contentFormatVersion)
        hasher.appendInt(syncState.rawValue)
        hasher.appendLengthPrefixed(remoteId ?? "")
        hasher.appendLengthPrefixed(keyId ?? "")
    }
}
