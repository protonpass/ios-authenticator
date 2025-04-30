//
// OptionShadowModifier.swift
// Proton Authenticator - Created on 29/04/2025.
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

import SwiftUI

private struct OptionShadowModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        switch colorScheme {
        case .light:
            content.shadow(color: .inputBorder, radius: 2, x: 0, y: 2)
        case .dark:
            content
        // swiftlint:disable:next todo
        // TODO: Make sure shadow's color could not be mixed to backgrounds with opacity
//                .shadow(color: .green, radius: 2, x: 0, y: -2)
        @unknown default:
            content
        }
    }
}

extension View {
    /// Drop shadow for option rows like "Digits", "Time interval" ...
    /// (shadow down for dark mode and shadow up for light mode)
    func optionShadow() -> some View {
        modifier(OptionShadowModifier())
    }
}
