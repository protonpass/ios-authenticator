//
// HapticsManager.swift
// Proton Authenticator - Created on 24/04/2025.
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

#if os(iOS)
import CoreHaptics
import UIKit
#elseif os(macOS)
import AppKit
#endif

public enum HapticFeedbackType {
    case impact(intensity: CGFloat)
    #if os(iOS)
    case notify(UINotificationFeedbackGenerator.FeedbackType)
    #elseif os(macOS)
    case notify(MacOSNotificationType)
    #endif
    case selection
}

#if os(macOS)
public enum MacOSNotificationType: Sendable {
    case success
    case warning
    case error
}
#endif

@MainActor
public protocol HapticsServicing {
    func perform(_ type: HapticFeedbackType)
}

public extension HapticsServicing {
    func callAsFunction(_ type: HapticFeedbackType) {
        perform(type)
    }
}

#if os(iOS)
@MainActor
public final class HapticsManager: HapticsServicing {
    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)
    private let notificationFeedback = UINotificationFeedbackGenerator()
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let settings: any SettingsServicing

    public init(settings: any SettingsServicing) {
        self.settings = settings
    }

    public func perform(_ type: HapticFeedbackType) {
        guard settings.hapticFeedbackEnabled else { return }

        switch type {
        case let .impact(intensity):
            impactFeedback.prepare()
            impactFeedback.impactOccurred(intensity: intensity)
        case let .notify(type):
            notificationFeedback.prepare()
            notificationFeedback.notificationOccurred(type)
        case .selection:
            selectionFeedback.prepare()
            selectionFeedback.selectionChanged()
        }
    }
}

#elseif os(macOS)
@MainActor
public final class HapticsManager: HapticsServicing {
    private let settings: any SettingsServicing
    private let feedbackPerformer = NSHapticFeedbackManager.defaultPerformer

    public init(settings: any SettingsServicing) {
        self.settings = settings
    }

    public func perform(_ type: HapticFeedbackType) {
        guard settings.hapticFeedbackEnabled else { return }

        switch type {
        case .impact:
            feedbackPerformer.perform(.levelChange, performanceTime: .now)

        case let .notify(type):
            let pattern: NSHapticFeedbackManager.FeedbackPattern = switch type {
            case .success:
                .levelChange
            case .warning:
                .alignment
            case .error:
                .generic
            }
            feedbackPerformer.perform(pattern, performanceTime: .now)

        case .selection:
            feedbackPerformer.perform(.alignment, performanceTime: .now)
        }
    }
}
#endif
