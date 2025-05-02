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
import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

import SDWebImageSwiftUI

private struct HighlightedText: View {
    let text: String
    let highlighted: String

    var body: some View {
        Text(attributedString) // ignore:missing_bundle
    }

    private var attributedString: AttributedString {
        var attributedString = AttributedString(text)

        if let range = attributedString.range(of: highlighted, options: .caseInsensitive) {
            attributedString[range].foregroundColor = Color.accentColor
        }
        return attributedString
    }
}

struct EntryCell: View {
    @Environment(\.colorScheme) private var colorScheme
    let entry: Entry
    let code: Code
    let configuration: EntryCellConfiguration
    let issuerInfos: AuthIssuerInfo?
    let searchTerm: String
    let onCopyToken: () -> Void
    @Binding var pauseCountDown: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                icon

                VStack(alignment: .leading) {
                    HighlightedText(text: entry.name, highlighted: searchTerm)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.textNorm)
                        .textShadow()
                    HighlightedText(text: entry.issuer, highlighted: searchTerm)
                        .font(.system(size: 14, weight: .regular))
                        .lineLimit(1)
                        .foregroundStyle(.textWeak)
                        .textShadow()
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                TOTPCountdownView(period: entry.period, pauseCountDown: $pauseCountDown)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)

            Rectangle()
                .foregroundStyle(.clear)
                .frame(maxWidth: .infinity, maxHeight: 0.5)
                .background(isLightMode ? .white : Color(red: 0.59, green: 0.59, blue: 0.59)
                    .opacity(0.4))
                .shadow(color: isLightMode ? Color(red: 0.87, green: 0.87, blue: 0.82) : .black.opacity(0.9),
                        radius: 0,
                        x: 0,
                        y: -0.5)

            HStack(alignment: configuration.digitStyle == .boxed ? .center : .bottom) {
                numberView
                    .animation(.bouncy, value: configuration.animateCodeChange ? code : .default)
                    .privacySensitive()

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 0) {
                    Text("Next", bundle: .module)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.textWeak)
                        .textShadow()
                    Text(verbatim: nextCode)
                        .font(.system(size: 15, weight: .semibold))
                        .monospaced()
                        .foregroundStyle(.textNorm)
                        .textShadow()
                        .privacySensitive()
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 12)
            .padding(.horizontal, 16)
        }
        .background(LinearGradient(stops:
            [
                Gradient.Stop(color: isLightMode ? .white : .white.opacity(0.11), location: 0.00),
                Gradient.Stop(color: isLightMode ? .white.opacity(0.9) : .white.opacity(0.1), location: 0.10),
                Gradient.Stop(color: isLightMode ? .white.opacity(0.5) : .white.opacity(0.1), location: 1)
            ],
            startPoint: UnitPoint(x: 0.5, y: 0),
            endPoint: UnitPoint(x: 0.5, y: 1)))
        .mainBackground()
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .simultaneousGesture(TapGesture()
            .onEnded {
                onCopyToken()
            })
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(LinearGradient(stops:
                [
                    Gradient.Stop(color: isLightMode ? Color.white : Color(red: 0.44, green: 0.44, blue: 0.42),
                                  location: 0.00),
                    Gradient.Stop(color: isLightMode ? Color.white.opacity(0.5) : Color(red: 0.31,
                                                                                        green: 0.3,
                                                                                        blue: 0.29),
                                  location: 1.00)
                ],
                startPoint: UnitPoint(x: 0.5, y: 0),
                endPoint: UnitPoint(x: 0.5, y: 1)),
            lineWidth: 0.5))
        .shadow(color: .black.opacity(isLightMode ? 0.12 : 0.16),
                radius: 4,
                x: 0,
                y: isLightMode ? 3 : 2)
    }

    private var isLightMode: Bool {
        colorScheme == .light
    }

    var nextCode: String {
        let text = configuration.hideEntryCode ? String(repeating: "•", count: code.next.count) : code.next
        return text.count > 6 ? text : text.separatedByGroup(3, delimiter: " ")
    }

    var mainCode: String {
        let code = configuration.hideEntryCode ? String(repeating: "•", count: code.current.count) : code.current
        return code.count > 6 ? code : code.separatedByGroup(3, delimiter: " ")
    }

    @ViewBuilder
    private var numberView: some View {
        if configuration.digitStyle == .boxed {
            HStack(alignment: .center, spacing: 6) {
                ForEach(Array(mainCode.enumerated()), id: \.offset) { _, char in
                    if char.isWhitespace {
                        Text(verbatim: " ")
                            .font(.system(size: 28, weight: .semibold))
                            .monospaced()
                            .foregroundStyle(.textNorm)
                    } else {
                        Text(verbatim: "\(char)")
                            .font(.system(size: 28, weight: .semibold))
                            .monospaced()
                            .foregroundStyle(.textNorm)
                            .contentTransition(.numericText())
                            .frame(minWidth: mainCode.count == 7 || mainCode.count == 6 ? 28 : 24, minHeight: 36)
                            .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(.shadow(.inner(color: .black.opacity(isLightMode ? 0.16 : 0.3),
                                                     radius: isLightMode ? 1 : 4,
                                                     x: 0,
                                                     y: isLightMode ? 1 : 2)))
                                .foregroundStyle(isLightMode ? Color(red: 0.95, green: 0.94, blue: 0.94) :
                                    Color(red: 0.19,
                                          green: 0.18,
                                          blue: 0.18)))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .shadow(color: .white.opacity(isLightMode ? 1 : 0.1), radius: 2, x: 0, y: 1)
                            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .inset(by: -0.25)
                                .stroke(.black.opacity(isLightMode ? 0.23 : 0.5), lineWidth: 0.5))
                    }
                }
            }
        } else {
            Text(verbatim: mainCode)
                .font(.system(size: 30, weight: .semibold))
                .kerning(3)
                .monospaced()
                .foregroundStyle(.textNorm)
                .contentTransition(.numericText())
                .textShadow()
        }
    }

    @ViewBuilder
    var icon: some View {
        if let iconUrl = issuerInfos?.iconUrl, let url = URL(string: iconUrl) {
            WebImage(url: url) { image in
                image.resizable()
            } placeholder: {
                letterDisplay
            }
            .indicator(.activity)
            .transition(.fade(duration: 0.5))
            .scaledToFit()
            .padding(4)
            .frame(width: 34, height: 34, alignment: .center)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .inset(by: -0.25)
                .stroke(isLightMode ? Color(red: 0.32, green: 0.16, blue: 0.47).opacity(0.3) : .black.opacity(0),
                        lineWidth: 0.5))
        } else {
            letterDisplay
        }
    }

    var letterDisplay: some View {
        Text(verbatim: "\(entry.issuer.first?.uppercased() ?? "")")
            .font(.system(size: 23, weight: .medium))
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
            .background(isLightMode ? Color(red: 0.95, green: 0.93, blue: 0.97).opacity(0.8) : .black.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .inset(by: -0.25)
                .stroke(isLightMode ? Color(red: 0.32, green: 0.16, blue: 0.47).opacity(0.3) : .black.opacity(0),
                        lineWidth: 0.5))
    }
}

private struct TOTPCountdownView: View {
    private let period: Int // TOTP period in seconds (typically 30 or 60)
    private let size: CGFloat // Diameter of the circle
    private let lineWidth: CGFloat // Thickness of the progress bar
    @Binding private var pauseCountDown: Bool

    init(period: Int,
         size: CGFloat = 32,
         lineWidth: CGFloat = 4,
         pauseCountDown: Binding<Bool>) {
        self.period = period
        self.size = size
        self.lineWidth = lineWidth
        _pauseCountDown = pauseCountDown
    }

    @State private var timeRemaining: Double = 0
    @State private var progress: CGFloat = 0.0
    @State private var timerCancellable: AnyCancellable?

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(lineWidth: 4)
                .animation(.default, value: progress)
                .foregroundStyle(color.opacity(0.3))
                .padding(2)

            // Progress circle
            Circle()
                .trim(from: 1 - progress, to: 1)
                .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                .foregroundStyle(color)
                .padding(2)
                .rotationEffect(.degrees(-90))
                .animation(.default, value: progress)
                .transaction { transaction in
                    transaction.disablesAnimations = timeRemaining == Double(period) - 1
                }

            // Countdown text
            Text(verbatim: "\(Int(timeRemaining))")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.textNorm)
        }
        .frame(width: size, height: size)
        .onAppear {
            calculateTime()
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
        .onChange(of: pauseCountDown) {
            if !pauseCountDown, timerCancellable == nil {
                startTimer()
            } else if pauseCountDown {
                stopTimer()
            }
        }
    }

    private func calculateTime() {
        let timeInterval = Date().timeIntervalSince1970
        let newPeriod = Double(period)
        timeRemaining = (newPeriod - timeInterval.truncatingRemainder(dividingBy: newPeriod)).rounded(.down)
        progress = CGFloat(timeRemaining) / CGFloat(period)
    }

    private func startTimer() {
        // Using a 0.1 second timer for smoother updates
        timerCancellable = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                calculateTime()
            }
    }

    private func stopTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    private var color: Color {
        switch timeRemaining {
        case 0...5:
            .timer1
        case 5...10:
            .timer2
        default:
            .timer3
        }
    }
}
