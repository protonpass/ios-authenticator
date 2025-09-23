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
import CommonUtilities
import Foundation
import Models

// MARK: - Message Model

public struct InAppMessage: Identifiable, Codable, Equatable {
    public let id: String
    public let title: String
    public let body: String
    public let type: MessageType

    public enum MessageType: String, Codable {
        case info, success, warning, error
    }

    public init(id: String = UUID().uuidString,
                title: String,
                body: String,
                type: MessageType = .info) {
        self.id = id
        self.title = title
        self.body = body
        self.type = type
    }
}

// MARK: - Persistence Protocol

public protocol MessagePersistence {
    func loadDismissedIDs() -> Set<String>
    func saveDismissedIDs(_ ids: Set<String>)
}

// Default implementation with UserDefaults
public final class UserDefaultsPersistence: MessagePersistence {
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

    private let store: any MessagePersistence
    private var dismissedIDs: Set<String>

    public init(store: any MessagePersistence) {
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

import SwiftUI

// MARK: - SwiftUI View

struct InAppMessageBanner: View {
    let message: InAppMessage
    let onDismiss: (Bool) -> Void

    var body: some View {
        VStack {
            HStack {
                VStack(alignment: .leading) {
                    Text(message.title).bold()
                    Text(message.body).font(.subheadline)
                }
                Spacer()
                Button("Hide") { onDismiss(true) }
            }
            .padding()
            .background(color(for: message.type))
            .cornerRadius(12)
            .shadow(radius: 4)
        }
        .padding()
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private func color(for type: InAppMessage.MessageType) -> Color {
        switch type {
        case .info: .blue.opacity(0.8)
        case .success: .green.opacity(0.8)
        case .warning: .orange.opacity(0.8)
        case .error: .red.opacity(0.8)
        }
    }
}

// MARK: - SwiftUI Modifier

struct InAppMessagingModifier: ViewModifier {
    @Environment(InAppMessagingService.self) private var service

    func body(content: Content) -> some View {
        ZStack {
            content
            if let message = service.currentMessage {
                VStack {
                    InAppMessageBanner(message: message,
                                       onDismiss: { permanently in
                                           service.dismiss(permanently: permanently)
                                       })
                    Spacer()
                }
            }
        }
        .animation(.spring(), value: service.currentMessage)
    }
}

public extension View {
    func inAppMessaging() -> some View {
        modifier(InAppMessagingModifier())
    }
}
