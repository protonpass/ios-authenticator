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

import Foundation

import DataLayer
import Factory
import SwiftUI

struct HapticButtonModifier: ViewModifier {
    @State private var haptics: HapticsServicing = resolve(\ToolsContainer.hapticsManager)
    let type: AuthHapticFeedbackType

    func body(content: Content) -> some View {
        content.simultaneousGesture(TapGesture().onEnded {
            haptics.execute(type)
        })
    }
}

extension View {
    @ViewBuilder
    func impactHaptic(impactIntensity: CGFloat = 1) -> some View {
        modifier(HapticButtonModifier(type: .impact(intensity: impactIntensity)))
    }

    #if os(iOS)
    func notificationHaptic(type: UINotificationFeedbackGenerator.FeedbackType = .success) -> some View {
        modifier(HapticButtonModifier(type: .notify(type: type)))
    }
    #endif

    @ViewBuilder
    func selectionHaptic() -> some View {
        #if os(iOS)
        modifier(HapticButtonModifier(type: .selection))
        #endif
    }
}

// struct HapticButtonStyle: ButtonStyle {
//    @State private var haptics: HapticsServicing = resolve(\ToolsContainer.hapticsManager)
//    let type: AuthHapticFeedbackType
//
//    func makeBody(configuration: Configuration) -> some View {
//        configuration.label
//            .onChange(of: configuration.isPressed) {
//                #if os(iOS)
//                if configuration.isPressed {
//                    haptics.execute(type)
//                }
//                #endif
//            }
//    }
// }
//
// extension Button {
//    @MainActor
//    func impactHaptic(impactIntensity: CGFloat = 1) -> some View {
//        buttonStyle(HapticButtonStyle(type: .impact(intensity: impactIntensity)))
//    }
//
//    @MainActor
//    func notificationHaptic(type: UINotificationFeedbackGenerator.FeedbackType = .success) -> some View {
//        buttonStyle(HapticButtonStyle(type: .notify(type: type)))
//    }
//
//    @MainActor
//    func selectionHaptic() -> some View {
//        buttonStyle(HapticButtonStyle(type: .selection))
//    }
// }
