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
import CoreHaptics
import Foundation
import UIKit

public enum AuthHapticFeedbackType {
    case impact(intensity: CGFloat)
    case notify(type: UINotificationFeedbackGenerator.FeedbackType)
    case selection
}

@MainActor
public protocol HapticsServicing {
    func execute(_ type: AuthHapticFeedbackType)
}

public final class HapticsManager: HapticsServicing {
    private let impactFeedBack = UIImpactFeedbackGenerator(style: .light)
    private let notificationFeedBack = UINotificationFeedbackGenerator()
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let settings: SettingsServicing

    public init(settings: SettingsServicing) {
        self.settings = settings
    }
}

public extension HapticsManager {
    func execute(_ type: AuthHapticFeedbackType) {
        guard settings.hapticFeedbackEnabled else { return }
        switch type {
        case let .impact(intensity):
            impact(intensity: intensity)
        case let .notify(type):
            notify(type: type)
        case .selection:
            selectionChanged()
        }
    }
}

private extension HapticsManager {
    func impact(intensity: CGFloat) {
        impactFeedBack.prepare()
        impactFeedBack.impactOccurred(intensity: intensity)
    }

    func notify(type: UINotificationFeedbackGenerator.FeedbackType) {
        notificationFeedBack.prepare()
        notificationFeedBack.notificationOccurred(type)
    }

    func selectionChanged() {
        selectionFeedback.prepare()
        selectionFeedback.selectionChanged()
    }
}
#endif
