//
// RequestForReview.swift
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

@preconcurrency import Combine
import DataLayer

public protocol RequestForReviewUseCase: Sendable {
    func execute() async
}

public extension RequestForReviewUseCase {
    func callAsFunction() async {
        await execute()
    }
}

public final class RequestForReview: RequestForReviewUseCase {
    private let reviewService: any ReviewServicing
    private let checkAskForReview: any CheckAskForReviewUseCase

    public init(reviewService: any ReviewServicing,
                checkAskForReview: any CheckAskForReviewUseCase) {
        self.reviewService = reviewService
        self.checkAskForReview = checkAskForReview
    }

    public func execute() async {
        if await checkAskForReview() {
            reviewService.askForReviewEventStream.send(())
        }
    }
}
