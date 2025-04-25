//
// HapticManager+ViewModifier.swift
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
import DataLayer
import Factory
import Foundation
import SwiftUI

private struct HapticModifier: ViewModifier {
    private let haptics = resolve(\ToolsContainer.hapticsManager)
    let type: HapticFeedbackType

    func body(content: Content) -> some View {
        content.simultaneousGesture(TapGesture().onEnded {
            haptics(type)
        })
    }
}

extension View {
    func impactHaptic(impactIntensity: CGFloat = 1) -> some View {
        modifier(HapticModifier(type: .impact(intensity: impactIntensity)))
    }

    func notificationHaptic(type: UINotificationFeedbackGenerator.FeedbackType = .success) -> some View {
        modifier(HapticModifier(type: .notify(type)))
    }

    // periphery:ignore
    func selectionHaptic() -> some View {
        modifier(HapticModifier(type: .selection))
    }
}
#endif
