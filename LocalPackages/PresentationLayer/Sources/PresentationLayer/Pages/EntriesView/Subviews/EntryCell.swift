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
            HStack(spacing: 8) {
                icon

                VStack(alignment: .leading) {
                    HighlightedText(text: entry.name, highlighted: searchTerm)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.textNorm)
                    HighlightedText(text: entry.issuer, highlighted: searchTerm)
                        .lineLimit(1)
                        .foregroundStyle(.textWeak)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                TOTPCountdownView(period: entry.period, pauseCountDown: $pauseCountDown)
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

            HStack(alignment: configuration.digitStyle == .boxed ? .center : .bottom) {
                numberView
                    .animation(.bouncy, value: configuration.animateCodeChange ? code : .default)
                    .privacySensitive()

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 3) {
                    Text("Next", bundle: .module)
                        .font(.custom("SF Pro Text", size: 14))
                        .foregroundStyle(.textWeak)
                    Text(verbatim: nextCode)
                        .font(.custom("SF Mono", size: 15).weight(.semibold))
                        .monospaced()
                        .foregroundStyle(.textNorm)
                        .shadow(color: .black.opacity(0.25), radius: 1, x: 0, y: 2)
                        .privacySensitive()
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(.white.opacity(0.1))
        }
        .onTapGesture(perform: onCopyToken)
        .background(LinearGradient(stops:
            [
                Gradient.Stop(color: .white, location: 0.00),
                Gradient.Stop(color: .white.opacity(isLightMode ? 0.5 : 0),
                              location: isLightMode ? 1.00 : 0.0)
            ],
            startPoint: UnitPoint(x: 0.5, y: 0),
            endPoint: UnitPoint(x: 0.5, y: 1)))
        .cornerRadius(18)
        .shadow(color: .black.opacity(0.16), radius: 4, x: 0, y: 2)
        .overlay(RoundedRectangle(cornerRadius: 18)
            .stroke(.white.opacity(0.16), lineWidth: 1))
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
        return code.count > 6 ? code : code.separatedByGroup(3, delimiter: " ")
    }

    @ViewBuilder
    private var numberView: some View {
        if configuration.digitStyle == .boxed {
            HStack(alignment: .center, spacing: 6) {
                ForEach(Array(mainCode.enumerated()), id: \.offset) { _, char in
                    if char.isWhitespace {
                        Text(verbatim: " ")
                            .font(.title)
                            .fontWeight(.semibold)
                            .foregroundStyle(.textNorm)
                    } else {
                        Text(verbatim: "\(char)")
                            .font(.title)
                            .fontWeight(.semibold)
                            .foregroundStyle(.textNorm)
                            .contentTransition(.numericText())
                            .frame(minWidth: mainCode.count == 7 ? 28 : 22, minHeight: 36)
                            .background(.black.opacity(0.16))
                            .cornerRadius(8)
                            .shadow(color: .white.opacity(0.1), radius: 1, x: 0, y: 1)
                            .overlay(RoundedRectangle(cornerRadius: 8)
                                .inset(by: -0.5)
                                .stroke(.black.opacity(0.23), lineWidth: 1))
                    }
                }
            }
        } else {
            Text(verbatim: mainCode)
                .font(.title)
                .fontWeight(.semibold)
                .foregroundStyle(.textNorm)
                .monospaced()
                .contentTransition(.numericText())
                .shadow(color: .black.opacity(0.25), radius: 1, x: 0, y: 2)
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
            .frame(width: 36, height: 36, alignment: .center)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            letterDisplay
        }
    }

    var letterDisplay: some View {
        Text(verbatim: "\(entry.issuer.first?.uppercased() ?? "")")
            .font(.title)
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
            .padding(.horizontal, 5)
            .padding(.vertical, 6)
            .frame(width: 36, height: 36, alignment: .center)
            .background(.black.opacity(0.16))
            .cornerRadius(8)
            .shadow(color: .white.opacity(0.1), radius: 1, x: 0, y: 1)
            .overlay(RoundedRectangle(cornerRadius: 8)
                .inset(by: -0.5)
                .stroke(.black.opacity(0.23), lineWidth: 1))
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

            // Progress circle
            Circle()
                .trim(from: 1 - progress, to: 1)
                .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                .foregroundStyle(color)
                .rotationEffect(.degrees(-90))
                .animation(.default, value: progress)
                .transaction { transaction in
                    transaction.disablesAnimations = timeRemaining == Double(period) - 1
                }

            // Countdown text
            Text(verbatim: "\(Int(timeRemaining))")
                .font(.custom("SF Compact Text", size: 12).weight(.semibold))
                .foregroundStyle(.textNorm)
                .monospacedDigit()
                .shadow(color: .black.opacity(0.25), radius: 1, x: 0, y: 2)
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
