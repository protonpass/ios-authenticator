//
// EditThemeView.swift
// Proton Authenticator - Created on 13/02/2025.
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
//

import Models
import SwiftUI

struct EditThemeView: View {
    @Environment(\.dismiss) private var dismiss
    let currentTheme: Theme
    let onUpdate: (Theme) -> Void

    var body: some View {
        VStack {
            ForEach(Theme.allCases, id: \.self) { theme in
                Button {
                    if theme == currentTheme {
                        dismiss()
                    } else {
                        dismiss()
                        onUpdate(theme)
                    }
                } label: {
                    HStack {
                        Text(theme.title)
                            .foregroundStyle(.textNorm)
                        Spacer()
                        if theme == currentTheme {
                            Image(systemName: "checkmark")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16)
                                .foregroundStyle(.textNorm)
                        }
                    }
                    .padding(8)
                }
                
                if theme != Theme.allCases.last {
                    Divider()
                }
            }
        }
        .presentationDetents([.height(CGFloat(60 * Theme.allCases.count))])
        .fullScreenMainBackground()
    }
}

extension Theme {
    var title: LocalizedStringKey {
        switch self {
        case .dark:
            "Dark"
        case .light:
            "Light"
        case .system:
            "Match system"
        }
    }
}
