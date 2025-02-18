//
// TokenUiModel.swift
// Proton Authenticator - Created on 17/02/2025.
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

public struct TokenUiModel: Sendable, Hashable {
    public let code: Code
    public let progress: Double
    public let countdown: Int

    public init(code: Code,
                progress: Double,
                countdown: Int) {
        self.code = code
        self.progress = progress
        self.countdown = countdown
    }
}

public extension TokenUiModel {
    init(entry: Entry, code: Code, date: Date) {
        let timeInterval = date.timeIntervalSince1970
        let period = Double(entry.period)
        let remaining = min(period - timeInterval.truncatingRemainder(dividingBy: period), period)

        self.code = code
        progress = remaining / Double(entry.period)
        countdown = Int(remaining)
    }
}
