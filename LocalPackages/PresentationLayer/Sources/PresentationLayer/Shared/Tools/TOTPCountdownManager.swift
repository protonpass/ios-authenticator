//
// TOTPCountdownManager.swift
// Proton Authenticator - Created on 25/07/2025.
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

import Combine
import Foundation
import SwiftUI

@MainActor
public protocol TOTPCountdownProtocol: Sendable, Observable {
    func startTimer()
    func stopTimer()
    func calculateCountdownInfo(period: Int) -> TOTPCountdownManager.CountdownInfo
}

@MainActor @Observable
public final class TOTPCountdownManager: TOTPCountdownProtocol {
    static let shared = TOTPCountdownManager()

    private var currentTimestamp: TimeInterval = Date().timeIntervalSince1970

    @ObservationIgnored
    private var timerCancellable: AnyCancellable?

    public struct CountdownInfo {
        let progress: Double
        let color: Color
        let timeRemaining: Int
    }

    private init() {
        startTimer()
    }

    public func startTimer() {
        guard timerCancellable == nil else { return }

        timerCancellable = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                currentTimestamp = Date().timeIntervalSince1970
            }
    }

    public func stopTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    public func calculateCountdownInfo(period: Int) -> TOTPCountdownManager.CountdownInfo {
        let period = Double(period)
        let timeRemaining = (period - currentTimestamp.truncatingRemainder(dividingBy: period)).rounded(.down)
        let progress = timeRemaining / period

        let color: Color = switch timeRemaining {
        case 0...5:
            .timer1
        case 5...10:
            .timer2
        default:
            .timer3
        }

        return CountdownInfo(progress: progress, color: color, timeRemaining: Int(timeRemaining))
    }
}
