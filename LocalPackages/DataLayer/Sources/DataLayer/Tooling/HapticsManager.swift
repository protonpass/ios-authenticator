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

#if os(iOS)
// periphery:ignore
import CommonUtilities
import CoreHaptics
import Foundation
import UIKit

public enum HapticFeedbackType {
    case impact(intensity: CGFloat)
    case notify(UINotificationFeedbackGenerator.FeedbackType)
    case selection

    public static var defaultImpact: Self {
        impact(intensity: 1)
    }
}

@MainActor
public protocol HapticsServicing {
    func perform(_ type: HapticFeedbackType)
}

public extension HapticsServicing {
    func callAsFunction(_ type: HapticFeedbackType) {
        perform(type)
    }
}

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
        guard settings.hapticFeedbackEnabled, AppConstants.isPhone else { return }

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
#endif
