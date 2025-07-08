//
// CurrentTokenView.swift
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

import Models
import SwiftUI

struct CurrentTokenView: View {
    let code: String
    let configuration: EntryCellConfiguration
    let showCopyBadge: Bool

    var body: some View {
        mainContent
            .animation(.bouncy, value: configuration.animateCodeChange ? code : "")
            .privacySensitive()
            .if(configuration.animateCodeChange) { view in
                view.contentTransition(.numericText())
            }
    }
}

private extension CurrentTokenView {
    @ViewBuilder
    var mainContent: some View {
        let textColor: Color = showCopyBadge ? .copyMessage : .textNorm
        if configuration.digitStyle == .boxed {
            HStack(alignment: .center, spacing: 6) {
                ForEach(Array(code.enumerated()), id: \.offset) { _, char in
                    BoxedDigit(char: char,
                               codeCount: code.count,
                               textColor: textColor)
                }
            }
        } else {
            Text(verbatim: code)
                .dynamicFont(size: 30, textStyle: .title1, weight: .semibold)
                .kerning(3)
                .monospaced()
                .foregroundStyle(textColor)
                .textShadow()
        }
    }
}

private struct BoxedDigit: View {
    let char: Character
    let codeCount: Int
    let textColor: Color

    var body: some View {
        if char.isWhitespace {
            Text(verbatim: " ")
                .dynamicFont(size: 28, textStyle: .title1, weight: .semibold)
                .monospaced()
                .foregroundStyle(textColor)
        } else {
            ZStack {
                Image(.digitBackground)
                    .resizable(capInsets: EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
                    .padding(-3)
                Text(verbatim: "\(char)")
                    .dynamicFont(size: 28, textStyle: .title1, weight: .semibold)
                    .monospaced()
                    .foregroundStyle(textColor)
            }
            .frame(width: codeCount == 7 || codeCount == 6 ? 28 : 24, height: 36)
        }
    }
}
