//
// EntryCell.swift
// Proton Authenticator - Created on 11/02/2025.
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

import Combine
import CommonUtilities
import Factory
import Models
import RenderMeThis
import SwiftUI

struct EntryCell: View {
    @Environment(\.colorScheme) private var colorScheme
    let entry: Entry
    let code: Code
    let progress: ProgressUiModel
    let configuration: EntryCellConfiguration
    let onCopyToken: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                HStack(alignment: .center, spacing: 10) {
                    Text(verbatim: "\(entry.issuer.first?.uppercased() ?? "")")
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundStyle(LinearGradient(gradient:
                            Gradient(colors: [
                                Color(red: 109 / 255, green: 74 / 255, blue: 255 / 255), // #6D4AFF
                                Color(red: 181 / 255, green: 120 / 255, blue: 217 / 255), // #B578D9
                                Color(red: 249 / 255, green: 175 / 255, blue: 148 / 255), // #F9AF94
                                Color(red: 255 / 255, green: 213 / 255, blue: 128 / 255) // #FFD580
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing))
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 6)
                .frame(width: 32, height: 32, alignment: .center)
                .background(.black.opacity(0.16))
                .cornerRadius(8)
                .shadow(color: .white.opacity(0.1), radius: 1, x: 0, y: 1)
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .inset(by: -0.5)
                    .stroke(.black.opacity(0.23), lineWidth: 1))

                VStack(alignment: .leading) {
                    Text(verbatim: entry.name)
                        .font(Font.custom("SF Pro Text", size: 18)
                            .weight(.medium))
                        .foregroundStyle(.textNorm)
                    Text(verbatim: entry.issuer)
                        .lineLimit(1)
                        .foregroundStyle(.textWeak)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                CircularProgressView(progress: progress)
                    .disableAnimations()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(.white.opacity(0.1))

            Rectangle()
                .foregroundStyle(.clear)
                .frame(maxWidth: .infinity, maxHeight: 0.5)
                .background(isLightMode ? .white : Color(red: 0.59, green: 0.59, blue: 0.59)
                    .opacity(0.5))
                .shadow(color: isLightMode ? Color(red: 0.87, green: 0.87, blue: 0.82) : .black.opacity(0.9),
                        radius: 0,
                        x: 0,
                        y: -0.5)

            HStack {
                numberView

                Spacer()

                VStack(alignment: .trailing) {
                    Text("Next")
                        .foregroundStyle(.textWeak)
                    Text(verbatim: nextCode.separatedByGroup(3, delimiter: " "))
                        .monospaced()
                        .foregroundStyle(.textNorm)
                        .fontWeight(.semibold)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(.white.opacity(0.1))
        }
        .background(LinearGradient(stops:
            [
                Gradient.Stop(color: .white, location: 0.00),
                Gradient.Stop(color: .white.opacity(isLightMode ? 0.5 : 0),
                              location: isLightMode ? 1.00 : 0.0)
            ],
            startPoint: UnitPoint(x: 0.5, y: 0),
            endPoint: UnitPoint(x: 0.5, y: 1)))
        .background(isLightMode ? .clear : .white.opacity(0.1))
        .cornerRadius(18)
        .shadow(color: .black.opacity(0.16), radius: 4, x: 0, y: 2)
        .overlay(RoundedRectangle(cornerRadius: 18)
            .stroke(.white.opacity(0.16), lineWidth: 1))
        .onTapGesture(perform: onCopyToken)
    }

    private var isLightMode: Bool {
        colorScheme == .light
    }

    var nextCode: String {
        configuration.hideEntryCode ? String(repeating: "•", count: code.next.count) : code.next
    }

    @ViewBuilder
    private var numberView: some View {
        let code = configuration.hideEntryCode ? String(repeating: "•", count: code.current.count) : code.current
        if configuration.displayNumberBackground {
            ForEach(Array(code.enumerated()), id: \.offset) { _, char in
                HStack(alignment: .center, spacing: 10) {
                    Text(verbatim: "\(char)")
                        .font(.title)
                        .fontWeight(.semibold)
                        .foregroundStyle(.textNorm)
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 4)
                .background(.black.opacity(0.16))
                .cornerRadius(8)
                .shadow(color: .white.opacity(0.1), radius: 1, x: 0, y: 1)
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .inset(by: -0.5)
                    .stroke(.black.opacity(0.23), lineWidth: 1))
            }
        } else {
            Text(verbatim: "\(code.separatedByGroup(3, delimiter: " "))")
                .font(.title)
                .fontWeight(.semibold)
                .foregroundStyle(.textNorm)
                .monospaced()
        }
    }
}

private extension EntryCell {
    var borderColor: Color {
        Color.passPurple.opacity(0.5)
    }

    var backgroundColor: Color {
        borderColor.opacity(0.5)
    }
}

private struct CircularProgressView: View {
    let progress: ProgressUiModel
    let size: CGFloat // Diameter of the circle
    let lineWidth: CGFloat // Thickness of the progress bar

    init(progress: ProgressUiModel,
         size: CGFloat = 32,
         lineWidth: CGFloat = 4) {
        self.progress = progress
        self.size = size
        self.lineWidth = lineWidth
    }

    var body: some View {
        ZStack {
            // Background Circle
            Circle()
                .stroke(progress.color.opacity(0.3), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .frame(width: size, height: size)

            // Progress Circle
            Circle()
                .trim(from: 1 - progress.value, to: 1)
                .stroke(progress.color,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: size, height: size)

            // Timer Text
            Text(verbatim: "\(progress.countdown)")
                .font(.caption)
                .foregroundStyle(.textNorm)
                .monospacedDigit()
        }
    }
}

private extension ProgressUiModel {
    var color: Color {
        switch level {
        case .level1: .timer1
        case .level2: .timer2
        case .level3: .timer3
        }
    }
}
