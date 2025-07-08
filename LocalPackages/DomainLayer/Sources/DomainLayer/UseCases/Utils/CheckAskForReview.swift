//
// CheckAskForReview.swift
// Proton Authenticator - Created on 17/06/2025.
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
//

import DataLayer
import Foundation

/// Return `true` if appropriate to ask for review, `false` otherwise
public protocol CheckAskForReviewUseCase: Sendable {
    func execute() async -> Bool
}

public extension CheckAskForReviewUseCase {
    func callAsFunction() async -> Bool {
        await execute()
    }
}

public final class CheckAskForReview: CheckAskForReviewUseCase {
    private let settingsService: any SettingsServicing
    private let entryDataService: any EntryDataServiceProtocol
    private let logger: any LoggerProtocol
    private let bundle: Bundle

    public init(settingsService: any SettingsServicing,
                entryDataService: any EntryDataServiceProtocol,
                logger: any LoggerProtocol,
                bundle: Bundle) {
        self.settingsService = settingsService
        self.entryDataService = entryDataService
        self.logger = logger
        self.bundle = bundle
    }

    public func execute() async -> Bool {
        if bundle.isQaBuild {
            logger.log(.debug, category: .ui, "Checking if should ask for review")
        }

        let installationDate = await Date(timeIntervalSince1970: settingsService.installationTimestamp)
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: installationDate, to: .now)

        guard let dayCount = components.day, dayCount >= 7 else {
            if bundle.isQaBuild {
                logger.log(.debug, category: .ui, "Skipped asking for review because too early")
            }
            return false
        }

        guard let count = await entryDataService.dataState.data?.count,
              count >= 4 else {
            if bundle.isQaBuild {
                logger.log(.debug, category: .ui, "Skipped asking for review because too few entries")
            }
            return false
        }

        if bundle.isQaBuild {
            logger.log(.debug, category: .ui, "Eligible for asking for review")
        }
        return true
    }
}
