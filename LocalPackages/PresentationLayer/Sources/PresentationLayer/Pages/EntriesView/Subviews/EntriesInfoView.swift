//
// EntriesInfoView.swift
// Proton Authenticator - Created on 13/10/2025.
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

import CommonUtilities
import DataLayer
import SwiftUI

struct EntriesInfoView: View {
    @Environment(\.colorScheme) private var colorScheme
    let message: InAppMessage
    let url: String

    var body: some View {
        VStack(spacing: 18) {
            Text(verbatim: message.title)
                .fontWeight(.semibold)
            Text(verbatim: message.body)
                .frame(maxWidth: .infinity)
            if let url = URL(string: url) {
                Link(destination: url) {
                    Text("Learn more", bundle: .module)
                        .dynamicFont(size: 17, textStyle: .body, weight: .semibold)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, DesignConstant.padding / 1.5)
                        .padding(.horizontal, DesignConstant.padding * 1.5)
                        .frame(maxWidth: AppConstants.isPhone ? .infinity : 450, alignment: .center)
                        .background(Capsule()
                            .fill(.shadow(.inner(color: .white.opacity(0.25), radius: 2, x: 0, y: 1)))
                            .foregroundStyle(LinearGradient(stops:
                                [
                                    Gradient.Stop(color: Color(red: 0.45, green: 0.31, blue: 1),
                                                  location: 0.00),
                                    Gradient.Stop(color: Color(red: 0.27, green: 0.19, blue: 0.6),
                                                  location: 1.00)
                                ],
                                startPoint: UnitPoint(x: 0.5, y: 0),
                                endPoint: UnitPoint(x: 0.5, y: 1))))
                        .shadow(color: Color(red: 0.6, green: 0.37, blue: 1).opacity(0.25),
                                radius: 12,
                                x: 0,
                                y: 1)
                        .overlay(Capsule()
                            .inset(by: 0.25)
                            .stroke(colorScheme == .dark ? .white.opacity(0.12) : .black.opacity(0.20),
                                    lineWidth: 0.5))
                        .clipShape(.capsule)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .presentationDragIndicator(.visible)
        .measureHeight { newHeight in
            ContentHeightDetent.height = newHeight
        }
        .presentationDetents([.custom(ContentHeightDetent.self)])
    }
}
