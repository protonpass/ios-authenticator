//
// AddEntryButton.swift
// Proton Authenticator - Created on 17/02/2026.
// Copyright (c) 2026 Proton Technologies AG
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

struct AddEntryButton: View {
    let size: CGFloat
    let action: () -> Void

    var body: some View {
        if #available(iOS 26, macOS 26, *) {
            Button(action: action) {
                Image(systemName: "plus")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size / 2.5, height: size / 2.5, alignment: .center)
                    .padding(size / 5)
            }
            .impactHaptic()
            .buttonBorderShape(.circle)
            .buttonStyle(.glassProminent)
            .tint(.accent)
            .accessibilityLabel("Create new code")
        } else {
            Button(action: action) {
                plusIcon
                    .frame(width: size, height: size, alignment: .center)
                    .coloredBackgroundButton(.circle)
            }
            .adaptiveButtonStyle()
            .impactHaptic()
            .accessibilityLabel("Create new code")
        }
    }

    private var plusIcon: some View {
        Image(systemName: "plus")
            .resizable()
            .frame(width: 20, height: 20)
            .foregroundStyle(.white)
    }
}
