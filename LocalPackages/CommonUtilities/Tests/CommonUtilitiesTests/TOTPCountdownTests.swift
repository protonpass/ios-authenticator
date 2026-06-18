//
// TOTPCountdownTests.swift
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

import CommonUtilities
import Foundation
import Testing

struct TOTPCountdownTests {
    @Test
    func `Full ring at the start of a period`() {
        // 990 is a multiple of 30 → no time elapsed in the period.
        let countdown = TOTPCountdown.make(at: Date(timeIntervalSince1970: 990), period: 30)
        #expect(countdown.fractionRemaining == 1)
        #expect(countdown.secondsRemaining == 30)
    }

    @Test
    func `Mid period on a whole second`() {
        // 1000 mod 30 == 10 elapsed → 20 seconds remaining.
        let countdown = TOTPCountdown.make(at: Date(timeIntervalSince1970: 1_000), period: 30)
        #expect(abs(countdown.fractionRemaining - (20.0 / 30.0)) < 0.0001)
        #expect(countdown.secondsRemaining == 20)
    }

    @Test
    func `Seconds remaining rounds down on a fractional instant`() {
        // 1000.5 mod 30 == 10.5 elapsed → 19.5 seconds remaining.
        let countdown = TOTPCountdown.make(at: Date(timeIntervalSince1970: 1_000.5), period: 30)
        #expect(abs(countdown.fractionRemaining - 0.65) < 0.0001)
        #expect(countdown.secondsRemaining == 19)
    }

    @Test
    func `Respects a non standard period`() {
        // 1000 mod 60 == 40 elapsed → 20 seconds remaining of a 60s window.
        let countdown = TOTPCountdown.make(at: Date(timeIntervalSince1970: 1_000), period: 60)
        #expect(abs(countdown.fractionRemaining - (20.0 / 60.0)) < 0.0001)
        #expect(countdown.secondsRemaining == 20)
    }

    @Test
    func `Non positive period yields a full static ring`() {
        let zero = TOTPCountdown.make(at: Date(timeIntervalSince1970: 1_000), period: 0)
        #expect(zero.fractionRemaining == 1)
        #expect(zero.secondsRemaining == 0)

        let negative = TOTPCountdown.make(at: Date(timeIntervalSince1970: 1_000), period: -30)
        #expect(negative.fractionRemaining == 1)
        #expect(negative.secondsRemaining == 0)
    }
}
