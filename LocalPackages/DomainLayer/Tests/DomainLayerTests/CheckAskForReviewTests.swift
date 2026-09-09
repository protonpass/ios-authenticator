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
import Testing

@MainActor
struct CheckAskForReviewTests {
    let entryService: MockedEntryDataService
    let sut: any CheckAskForReviewUseCase

    init() {
        entryService = .init()
        sut = CheckAskForReview(entryDataService: entryService,
                                logger: MockLogger(),
                                bundle: .main)
    }

    @Test
    func `Skip asking for review when entries are not loaded yet`() async {
        let shouldAskForReview = await sut.execute()
        #expect(!shouldAskForReview)
    }

    @Test
    func `Skip asking for review when entries failed to load`() async {
        entryService.dataState = .failed(CancellationError())
        let shouldAskForReview = await sut.execute()
        #expect(!shouldAskForReview)
    }

    @Test
    func `Skip asking for review when no entries`() async {
        entryService.dataState = .loaded([])
        let shouldAskForReview = await sut.execute()
        #expect(!shouldAskForReview)
    }

    @Test
    func `Ask for review as soon as there is one entry`() async {
        entryService.dataState = .loaded([.random()])
        let shouldAskForReview = await sut.execute()
        #expect(shouldAskForReview)
    }
}
