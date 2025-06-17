//
// CheckAskForReviewTests.swift
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
import DomainLayer
import Foundation
import Testing

@MainActor
struct CheckAskForReviewTests {
    let settingsService: MockedSettingsService
    let entryService: MockedEntryDataService
    let sut: any CheckAskForReviewUseCase

    init() {
        settingsService = .init()
        entryService = .init()
        sut = CheckAskForReview(settingsService: settingsService,
                                         entryDataService: entryService,
                                         logger: MockLogger())
    }

    @Test("Skip asking for review when installed less than 7 days")
    func tooEarly() async {
        settingsService.installationTimestamp = Date.now.timeIntervalSince1970
        let shouldAskForReview = await sut.execute()
        #expect(!shouldAskForReview)
    }

    @Test("Skip asking for review when less than 4 entries")
    func tooFewEntries() async throws {
        let calendar = Calendar.current
        let sevenDaysBefore = try #require(calendar.date(byAdding: .day, value: -7, to: .now))
        settingsService.installationTimestamp = sevenDaysBefore.timeIntervalSince1970
        entryService.dataState = .loaded([.random()])
        let shouldAskForReview = await sut.execute()
        #expect(!shouldAskForReview)
    }

    @Test("Ask for review")
    func askForReview() async throws {
        let calendar = Calendar.current
        let sevenDaysBefore = try #require(calendar.date(byAdding: .day, value: -7, to: .now))
        settingsService.installationTimestamp = sevenDaysBefore.timeIntervalSince1970
        entryService.dataState = .loaded([.random(), .random(), .random(), .random()])
        let shouldAskForReview = await sut.execute()
        #expect(shouldAskForReview)
    }
}
