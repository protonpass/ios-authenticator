//
// TOTPCountdown.swift
// Proton Authenticator - Created on 12/06/2026.
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

import Foundation

/// A pure, value-type snapshot of a TOTP countdown at a single moment in time.
///
/// It is derived from a `Date` and the entry's `period` with no shared state and no timer, so a
/// SwiftUI `TimelineView` can compute it directly from the timeline's date. That lets SwiftUI
/// schedule (and pause) redraws per view — when off-screen or backgrounded — instead of a global
/// `@Observable` mutated twice a second by a `Combine` timer, which forced every visible ring to
/// recompute and animate continuously regardless of visibility.
///
/// Color mapping is intentionally left to the call site: iOS maps the countdown to a color by the
/// remaining whole seconds, whereas watchOS maps it by the remaining fraction.
public struct TOTPCountdown: Sendable, Equatable {
    /// Fraction of the period still remaining, in `0...1` (continuous, not quantized).
    public let fractionRemaining: Double

    /// Whole seconds still remaining, rounded down.
    public let secondsRemaining: Int

    public init(fractionRemaining: Double, secondsRemaining: Int) {
        self.fractionRemaining = fractionRemaining
        self.secondsRemaining = secondsRemaining
    }

    /// Computes the countdown for a `period`-second window at the given `date`.
    ///
    /// - Parameters:
    ///   - date: The reference time (defaults to now).
    ///   - period: The TOTP period in seconds. A non-positive value yields a full, static ring.
    public static func make(at date: Date = .now, period: Int) -> Self {
        guard period > 0 else {
            return Self(fractionRemaining: 1, secondsRemaining: 0)
        }
        let period = Double(period)
        let elapsedInPeriod = date.timeIntervalSince1970.truncatingRemainder(dividingBy: period)
        let remaining = period - elapsedInPeriod
        // Count `period-1 … 0` (e.g. 29→0 for a 30s window): the number reaches 0 in the final second
        // and resets to `period-1` at the boundary, in lockstep with the code change and the ring
        // emptying. (`rounded(.up) - 1` keeps it in `0...(period-1)` for any `remaining` in `(0, period]`.)
        return Self(fractionRemaining: remaining / period,
                    secondsRemaining: Int(remaining.rounded(.up)) - 1)
    }
}
