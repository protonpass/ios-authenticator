//
// EventsRepository.swift
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

import CommonUtilities
import Foundation
import ProtonCoreServices

public protocol EventsRepositoryProtocol: Sendable {
    func latestCoreEventId() -> String?
    func latestRemoteCoreEventId() async throws -> String
    func event(id: String) async throws -> CoreEventsResponse
    func save(id: String)
}

public final class EventsRepository: EventsRepositoryProtocol {
    private let apiClient: any APIClientProtocol
    private let store: UserDefaults
    private let logger: any LoggerProtocol

    public init(apiClient: any APIClientProtocol,
                store: UserDefaults,
                logger: any LoggerProtocol) {
        self.apiClient = apiClient
        self.store = store
        self.logger = logger
    }
}

public extension EventsRepository {
    func latestCoreEventId() -> String? {
        guard let stored = store.string(forKey: AppConstants.Settings.lastCoreEventId),
              !stored.isEmpty else {
            return nil
        }
        return stored
    }

    func latestRemoteCoreEventId() async throws -> String {
        do {
            return try await apiClient.getLatestCoreEventId()
        } catch {
            log(.error, "Failed to get latest remote core event id: \(error.localizedDescription)")
            throw error
        }
    }

    func event(id: String) async throws -> CoreEventsResponse {
        do {
            return try await apiClient.getCoreEvent(id: id)
        } catch {
            log(.error, "Failed to get core event for \(id): \(error.localizedDescription)")
            throw error
        }
    }

    func save(id: String) {
        store.set(id, forKey: AppConstants.Settings.lastCoreEventId)
    }
}

private extension EventsRepository {
    func log(_ level: LogLevel, _ message: String, function: String = #function, line: Int = #line) {
        logger.log(level, category: .data, message, function: function, line: line)
    }
}
