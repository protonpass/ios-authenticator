//
// InAppMessagingService.swift
// Proton Authenticator - Created on 23/09/2025.
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
import Models

// MARK: - Message Model

public struct InAppMessage: Identifiable, Codable, Equatable {
    public let id: String
    public let title: String
    public let body: String

    public init(id: String,
                title: String,
                body: String) {
        self.id = id
        self.title = title
        self.body = body
    }
}

// MARK: - Persistence Protocol

public protocol InAppMessagePersistence {
    func loadDismissedIDs() -> Set<String>
    func saveDismissedIDs(_ ids: Set<String>)
}

// Default implementation with UserDefaults
public final class UserDefaultsInAppMessagePersistence: InAppMessagePersistence {
    private let key = "dismissed_in_app_messages"
    private let store: UserDefaults

    public init(store: UserDefaults = .standard) {
        self.store = store
    }

    public func loadDismissedIDs() -> Set<String> {
        Set(store.stringArray(forKey: key) ?? [])
    }

    public func saveDismissedIDs(_ ids: Set<String>) {
        store.set(Array(ids), forKey: key)
    }
}

@MainActor
public protocol InAppMessagingServicing: Observable {
    var currentMessage: InAppMessage? { get set }

    func show(_ message: InAppMessage)
    func dismiss(permanently: Bool)
}

@MainActor
@Observable
public final class InAppMessagingService: InAppMessagingServicing {
    public var currentMessage: InAppMessage?

    private let store: any InAppMessagePersistence
    @ObservationIgnored
    private var dismissedIDs: Set<String>

    public init(store: any InAppMessagePersistence) {
        self.store = store
        dismissedIDs = store.loadDismissedIDs()
    }

    public func show(_ message: InAppMessage) {
        guard !dismissedIDs.contains(message.id) else { return }
        currentMessage = message
    }

    public func dismiss(permanently: Bool) {
        guard let message = currentMessage else { return }
        if permanently {
            dismissedIDs.insert(message.id)
            store.saveDismissedIDs(dismissedIDs)
        }
        currentMessage = nil
    }
}
