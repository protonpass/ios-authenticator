//
// LegacyMutex.swift
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

import Foundation
import os

public final class LegacyMutex<Value: Sendable>: Sendable {
    private let lock: OSAllocatedUnfairLock<Value>

    public init(_ value: Value) {
        lock = .init(uncheckedState: value)
    }

    public var value: Value {
        lock.withLock { $0 }
    }

    public func withLock<T: Sendable>(_ block: @Sendable (Value) throws -> T) rethrows -> T {
        try lock.withLock { value in
            try block(value)
        }
    }

    @discardableResult
    public func modify<T: Sendable>(_ block: @Sendable (inout Value) throws -> T) rethrows -> T {
        try lock.withLock { value in
            try block(&value)
        }
    }
}
