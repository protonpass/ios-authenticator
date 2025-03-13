//
// AlertService.swift
// Proton Authenticator - Created on 13/03/2025.
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
import SwiftUI

public struct AlertConfiguration: Sendable {
    public let title: String
    public let message: String?
    public let actions: [ActionConfig]

    public init(title: String, message: String?, actions: [ActionConfig]) {
        self.title = title
        self.message = message
        self.actions = actions
    }
}

public enum ActionRole: Sendable {
    case generic
    case cancel
    case destructive

    public var role: ButtonRole? {
        switch self {
        case .generic:
            nil
        case .cancel:
            .cancel
        case .destructive:
            .destructive
        }
    }
}

public struct ActionConfig: Sendable, Identifiable {
    public let id: String = UUID().uuidString
    public let title: String
    public let role: ActionRole
    public let action: (@Sendable () -> Void)?

    public init(title: String, role: ActionRole = .generic, action: (@Sendable () -> Void)? = nil) {
        self.title = title
        self.role = role
        self.action = action
    }
}

@MainActor
public protocol AlertServiceProtocol: Sendable, Observable {
    associatedtype ActionView: View

    @ViewBuilder
    var buildActions: ActionView { get }
    var alert: AlertConfiguration? { get }
    var isShowingAlert: Bool { get set }

    func showAlert(_ config: AlertConfiguration)
    func showError(_ error: Error)
}

@MainActor
@Observable
public final class AlertService: AlertServiceProtocol {
    public private(set) var alert: AlertConfiguration? {
        didSet { isShowingAlert = alert != nil }
    }

    public var isShowingAlert = false

    public init() {
        alert = alert
        isShowingAlert = isShowingAlert
    }

    public func showAlert(_ config: AlertConfiguration) {
        alert = config
    }

    public func showError(_ error: Error) {
        alert = AlertConfiguration(title: "An error occurred",
                                   message: error.localizedDescription,
                                   actions: [.init(title: "Ok", role: .cancel)])
    }

    @ViewBuilder
    public var buildActions: some View {
        ForEach(alert?.actions ?? []) { actionConfig in
            if let role = actionConfig.role.role {
                Button(role: role) {
                    actionConfig.action?()
                } label: {
                    Text("OK")
                }
            } else {
                Button(action: actionConfig.action ?? {}) {
                    Text(actionConfig.title)
                }
            }
        }
    }
}
