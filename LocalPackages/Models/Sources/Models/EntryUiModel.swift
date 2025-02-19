//
// EntryUiModel.swift
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

public struct EntryUiModel: Sendable, Identifiable {
    public let entry: Entry
    public let code: Code
    public let progress: ProgressUiModel

    public var id: String {
        entry.id
    }

    public init(entry: Entry,
                code: Code,
                progress: ProgressUiModel) {
        self.entry = entry
        self.code = code
        self.progress = progress
    }
}

public extension EntryUiModel {
    init(entry: Entry, code: Code, date: Date) {
        let timeInterval = date.timeIntervalSince1970
        let period = Double(entry.period)
        let remaining = min(period - timeInterval.truncatingRemainder(dividingBy: period), period)

        self.entry = entry
        self.code = code
        progress = .init(value: remaining / Double(entry.period), countdown: Int(remaining))
    }
}

public struct ProgressUiModel: Sendable {
    /// From 0.0 to 1.0
    public let value: Double
    public let level: Level
    /// Number of second left
    public let countdown: Int

    /// The less the level, the more critical it is
    public enum Level: Sendable {
        case level1, level2, level3, level4, level5, level6
    }

    public init(value: Double, countdown: Int) {
        self.value = value
        self.countdown = countdown

        level = switch value {
        case 0.0...0.08:
            .level1
        case 0.08...0.16:
            .level2
        case 0.16...0.25:
            .level3
        case 0.25...0.33:
            .level4
        case 0.33...0.4:
            .level5
        default:
            .level6
        }
    }
}
