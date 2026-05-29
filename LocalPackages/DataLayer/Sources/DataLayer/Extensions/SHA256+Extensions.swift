//
// SHA256+Extensions.swift
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

extension SHA256 {
    /// Length-prefixed UTF-8 string update, removing boundary ambiguity between adjacent fields.
    mutating func appendLengthPrefixed(_ value: String?) {
        guard let value else {
            return
        }
        let bytes = Data(value.utf8)
        var length = UInt32(bytes.count).bigEndian
        update(data: Data(bytes: &length, count: MemoryLayout<UInt32>.size))
        update(data: bytes)
    }

    /// Fixed-width big-endian `Int64` update, stable across 32/64-bit architectures.
    mutating func appendInt(_ value: Int) {
        var big = Int64(value).bigEndian
        update(data: Data(bytes: &big, count: MemoryLayout<Int64>.size))
    }
}
