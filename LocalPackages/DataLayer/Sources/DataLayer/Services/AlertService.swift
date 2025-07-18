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
import Models
import SwiftUI

public struct AlertConfiguration: Sendable, Identifiable {
    public let id: String = UUID().uuidString
    public let title: LocalizedStringKey
    public let titleBundle: Bundle
    public let message: TextContent?
    public let actions: [ActionConfig]

    public init(title: LocalizedStringKey,
                titleBundle: Bundle,
                message: TextContent?,
                actions: [ActionConfig]) {
        self.title = title
        self.titleBundle = titleBundle
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
    public let title: LocalizedStringKey
    public let titleBundle: Bundle
    public let role: ActionRole
    public let action: (@MainActor () -> Void)?

    public init(title: LocalizedStringKey,
                titleBundle: Bundle,
                role: ActionRole = .generic,
                action: (@MainActor () -> Void)? = nil) {
        self.title = title
        self.titleBundle = titleBundle
        self.role = role
        self.action = action
    }

    public static var ok: ActionConfig {
        .init(title: "OK", titleBundle: .module, role: .generic, action: {})
    }

    // periphery:ignore
    public static var cancel: ActionConfig {
        .init(title: "Cancel", titleBundle: .module, role: .cancel, action: {})
    }
}

@MainActor
public protocol AlertServiceProtocol: Sendable, Observable {
    var alert: AlertDisplay? { get }
    var showMainAlert: Bool { get set }
    var showSheetAlert: Bool { get set }
    var isShowingAlert: Bool { get }

    func resetAlert()
    func showAlert(_ alertDisplay: AlertDisplay)
    func showError(_ error: String, mainDisplay: Bool, action: (@MainActor () -> Void)?)
}

public extension AlertServiceProtocol {
    func showError(_ error: String, mainDisplay: Bool = true, action: (@MainActor () -> Void)? = nil) {
        showError(error, mainDisplay: mainDisplay, action: action)
    }

    func showError(_ error: any Error,
                   mainDisplay: Bool = true,
                   action: (@MainActor () -> Void)? = nil) {
        let errorMessage = if let authError = error as? CustomDebugStringConvertible,
                              error.localizedDescription != authError.debugDescription {
            "\(error.localizedDescription). \(authError.debugDescription)."
        } else {
            error.localizedDescription
        }
        showError(errorMessage, mainDisplay: mainDisplay, action: action)
    }
}

public enum AlertDisplay: Identifiable {
    case main(AlertConfiguration)
    case sheet(AlertConfiguration)

    public var configuration: AlertConfiguration {
        switch self {
        case let .main(config):
            config
        case let .sheet(config):
            config
        }
    }

    public var title: LocalizedStringKey {
        configuration.title
    }

    public var titleBundle: Bundle {
        configuration.titleBundle
    }

    public var message: TextContent? {
        configuration.message
    }

    public var actions: some View {
        ForEach(configuration.actions) { actionConfig in
            if let role = actionConfig.role.role {
                Button(role: role) {
                    actionConfig.action?()
                } label: {
                    Text(actionConfig.title, bundle: actionConfig.titleBundle)
                }
            } else {
                Button(action: actionConfig.action ?? {}) {
                    Text(actionConfig.title, bundle: actionConfig.titleBundle)
                }
            }
        }
    }

    public var id: String { configuration.id }
}

@MainActor
@Observable
public final class AlertService: AlertServiceProtocol {
    public var alert: AlertDisplay? {
        didSet {
            // Update the appropriate alert visibility based on the type
            switch alert {
            case .main:
                showMainAlert = true
                showSheetAlert = false
            case .sheet:
                showMainAlert = false
                showSheetAlert = true
            case nil:
                showMainAlert = false
                showSheetAlert = false
            }
        }
    }

    public var showMainAlert = false
    public var showSheetAlert = false

    public var isShowingAlert: Bool {
        showMainAlert || showSheetAlert
    }

    public init() {}

    public func showAlert(_ alertDisplay: AlertDisplay) {
        alert = alertDisplay
    }

    public func resetAlert() {
        alert = nil
    }

    public func showError(_ error: String, mainDisplay: Bool, action: (@MainActor () -> Void)?) {
        let config = AlertConfiguration(title: "An error occurred",
                                        titleBundle: .module,
                                        message: .verbatim(error),
                                        actions: [.init(title: "OK",
                                                        titleBundle: .module,
                                                        role: .cancel,
                                                        action: action)])
        alert = mainDisplay ? .main(config) : .sheet(config)
    }
}
