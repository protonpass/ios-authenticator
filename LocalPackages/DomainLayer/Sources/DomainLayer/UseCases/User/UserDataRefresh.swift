//
//
// UserDataRefresh.swift
// Proton Authenticator - Created on 13/05/2026.
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
//

import CommonUtilities
import DataLayer
import Foundation
import Models
import ProtonCoreAuthentication
@preconcurrency import ProtonCoreDataModel
@preconcurrency import ProtonCoreLogin
import ProtonCoreNetworking
import ProtonCoreServices

public protocol RefreshUserDataUseCase: Sendable {
    func callAsFunction() async throws
}

public struct UserDataRefresh: RefreshUserDataUseCase {
    private let userSessionManager: any UserSessionTooling
    private let eventsRepository: any EventsRepositoryProtocol
    private let logger: any LoggerProtocol
    private let passphraseBuilder: any PassphraseRebuilding

    public init(userSessionManager: any UserSessionTooling,
                eventsRepository: any EventsRepositoryProtocol,
                passphraseBuilder: any PassphraseRebuilding,
                logger: any LoggerProtocol) {
        self.userSessionManager = userSessionManager
        self.eventsRepository = eventsRepository
        self.logger = logger
        self.passphraseBuilder = passphraseBuilder
    }

    public func callAsFunction() async throws {
        guard let oldUserData = userSessionManager.userData else {
            return
        }
        try Task.checkCancellation()
        logger.log(.info, category: .network, "Start syncing core events")

        guard try await shouldRefreshUser() else {
            logger.log(.info,
                       category: .network,
                       "Core event refresh: No update action needed, skipping")
            return
        }
        try Task.checkCancellation()
        async let updatedUserData = userSessionManager.getLatestUserData(oldUserData)
        async let fetchLatestEVentId = eventsRepository.latestRemoteCoreEventId()
        let (newUserData, latestEventId) = try await (updatedUserData, fetchLatestEVentId)

        try await userSessionManager.save(newUserData)
        eventsRepository.save(id: latestEventId)
        logger.log(.info, category: .network, "Updated user data")
    }

    func shouldRefreshUser() async throws -> Bool {
        guard let currentEventId = eventsRepository.latestCoreEventId() else {
            return true
        }

        try Task.checkCancellation()
        let result = try await eventsRepository.event(id: currentEventId)

        return result.shouldRefreshUserData
    }
}

private extension CoreEventsResponse {
    var shouldRefreshUserData: Bool {
        let events = (users ?? []) + (addresses ?? [])
        return events.contains(where: { $0.action == .update }) || refresh
    }
}
