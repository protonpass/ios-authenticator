//
// ShapeStyle+Extensions.swift
// Proton Authenticator - Created on 10/02/2025.
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

// extension ShapeStyle where Self == Color {
//    static var backgroundGradient: LinearGradient {
////        LinearGradient(gradient: Gradient(stops: [
////            .init(color: Color.gradientStart, location: 0.00),
////            .init(color: Color.gradientEnd, location: 1.00)
////        ]),
////        startPoint: UnitPoint(x: 0.5, y: 0),
////        endPoint: UnitPoint(x: 0.5, y: 1))
////
//        LinearGradient(stops: [
//            Gradient.Stop(color: Color(red: 0.18, green: 0.16, blue: 0.16), location: 0.00),
//            Gradient.Stop(color: Color(red: 0.09, green: 0.08, blue: 0.08), location: 1.00)
//        ],
//        startPoint: UnitPoint(x: 0.5, y: 0),
//        endPoint: UnitPoint(x: 0.5, y: 1))
//    }
// }

// TODO: need to have background on all screen and no safe area

struct MainBackgroundColor: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(Image(.backgroundTexture)
                .resizable(resizingMode: .tile)
                .opacity(0.15)
                .blendMode(colorScheme == .light ? .difference : .screen))
            .background(LinearGradient(stops: [
                    Gradient.Stop(color: Color.gradientStart, location: 0.00),
                    Gradient.Stop(color: Color.gradientEnd, location: 1.00)
                ],
                startPoint: UnitPoint(x: 0.5, y: 0),
                endPoint: UnitPoint(x: 0.5, y: 1)))
    }
}
