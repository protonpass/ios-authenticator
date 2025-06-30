//
// EntryThumbnail.swift
// Proton Authenticator - Created on 27/06/2025.
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

import SDWebImageSwiftUI
import SwiftUI

struct EntryThumbnail: View {
    @Environment(\.colorScheme) private var colorScheme
    let iconUrl: String?
    let letter: String

    var body: some View {
        if let iconUrl, let url = URL(string: iconUrl) {
            WebImage(url: url) { image in
                image
                    .resizable()
                    .background(.white)
            } placeholder: {
                thumbnailLetter
            }
            .transition(.fade(duration: 0.5))
            .frame(width: 34, height: 34, alignment: .center)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .inset(by: -0.25)
                .stroke(strokeColor, lineWidth: 0.5))
        } else {
            thumbnailLetter
        }
    }

    private var thumbnailLetter: some View {
        ThumbnailLetter(text: letter, strokeColor: strokeColor)
    }

    private var strokeColor: Color {
        colorScheme.isLight ?
            Color(red: 0.32, green: 0.16, blue: 0.47).opacity(0.3) : .black.opacity(0)
    }
}

private struct ThumbnailLetter: View {
    @Environment(\.colorScheme) private var colorScheme
    let text: String
    let strokeColor: Color

    var body: some View {
        Text(verbatim: text)
            .dynamicFont(size: 23, textStyle: .title2, weight: .medium)
            .foregroundStyle(LinearGradient(gradient:
                Gradient(colors: [
                    Color(red: 109 / 255, green: 74 / 255, blue: 255 / 255), // #6D4AFF
                    Color(red: 181 / 255, green: 120 / 255, blue: 217 / 255), // #B578D9
                    Color(red: 249 / 255, green: 175 / 255, blue: 148 / 255), // #F9AF94
                    Color(red: 255 / 255, green: 213 / 255, blue: 128 / 255) // #FFD580
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing))
            .padding(.horizontal, 3)
            .padding(.vertical, 4)
            .frame(width: 34, height: 34, alignment: .center)
            .background(colorScheme.isLight ?
                Color(red: 0.95, green: 0.93, blue: 0.97).opacity(0.8) : .black.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .inset(by: -0.25)
                .stroke(strokeColor, lineWidth: 0.5))
    }
}
