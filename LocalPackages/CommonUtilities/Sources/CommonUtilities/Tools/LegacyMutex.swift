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

// periphery:ignore:all

import Foundation
import os
#if canImport(Synchronization)
import Synchronization
#endif

/// A type-erasing protocol for mutex implementations
public protocol MutexProtected<Value>: Sendable {
    associatedtype Value: Sendable

    var value: Value { get }

    func withLock<T: Sendable>(_ block: @Sendable (Value) throws -> T) rethrows -> T

    @discardableResult
    func modify<T: Sendable>(_ block: @Sendable (inout Value) throws -> T) rethrows -> T
}

/// Legacy mutex implementation using OSAllocatedUnfairLock
public final class LegacyMutex<Value: Sendable>: MutexProtected {
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
        try lock.withLock { state in
            try block(&state)
        }
    }
}

@available(iOS 18.0, macOS 15.0, *)
public final class NativeMutex<Value: Sendable>: MutexProtected {
    private let mutex: Mutex<Value>

    public init(_ value: Value) {
        mutex = Mutex(value)
    }

    public var value: Value {
        mutex.withLock { $0 }
    }

    public func withLock<T: Sendable>(_ block: @Sendable (Value) throws -> T) rethrows -> T {
        try mutex.withLock { value in
            try block(value)
        }
    }

    @discardableResult
    public func modify<T: Sendable>(_ block: @Sendable (inout Value) throws -> T) rethrows -> T {
        try mutex.withLock { value in
//            var mutableValue = value
//            let result = try block(&mutableValue)
//            value = mutableValue // Update the original value
//            return result
            try block(&value)
        }
    }
}

/// Factory that creates the appropriate mutex implementation based on availability
public enum SafeMutex {
    /// Creates a thread-safe mutex wrapper for the provided value
    /// using the most appropriate implementation based on platform availability.
    /// - Parameter value: The initial value to protect
    /// - Returns: A thread-safe wrapper conforming to MutexProtocol
    public static func create<Value: Sendable>(_ value: Value) -> any MutexProtected<Value> {
        if #available(iOS 18.0, macOS 15.0, *) {
            NativeMutex(value)
        } else {
            LegacyMutex(value)
        }
    }
}
