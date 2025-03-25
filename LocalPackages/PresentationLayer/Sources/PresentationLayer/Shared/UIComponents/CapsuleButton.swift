//
// CapsuleButton.swift
// Proton Authenticator - Created on 19/03/2025.
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

struct CapsuleButton: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: LocalizedStringKey
    let textColor: Color
    let style: Style
    var height: CGFloat = 52
    let action: () -> Void

    enum Style {
        case borderedFilled, bordered
    }

    var body: some View {
        Button(action: action) {
            switch style {
            case .borderedFilled:
                borderedFilledText
            case .bordered:
                borderedText
            }
        }
        .frame(height: height)
    }
}

private extension CapsuleButton {
    var text: some View {
        Text(title)
            .fontWeight(.semibold)
            .foregroundStyle(textColor)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding()
    }

    var borderedFilledText: some View {
        text
            .background(LinearGradient(stops:
                [
                    .init(color: Color(red: 0.45, green: 0.31, blue: 1), location: 0.00),
                    .init(color: Color(red: 0.27, green: 0.19, blue: 0.6), location: 1.00)
                ],
                startPoint: UnitPoint(x: 0.5, y: 0),
                endPoint: UnitPoint(x: 0.5, y: 1)))
            .shadow(color: Color(red: 0.6, green: 0.37, blue: 1).opacity(0.25),
                    radius: 12,
                    x: 0,
                    y: 1)
            .overlay(Capsule()
                .inset(by: 0.25)
                .stroke(.white.opacity(0.12), lineWidth: 0.5))
            .clipShape(.capsule)
    }

    var borderedText: some View {
        text
            .overlay(RoundedRectangle(cornerRadius: 26)
                .inset(by: 0.25)
                .stroke(colorScheme == .dark ? .white.opacity(0.32) : .black.opacity(0.18),
                        lineWidth: 0.5))
    }
}
