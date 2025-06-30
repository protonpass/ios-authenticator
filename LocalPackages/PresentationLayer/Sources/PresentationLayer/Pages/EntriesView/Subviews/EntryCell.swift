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
import FactoryKit
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
    @State private var showCopyBadge = false
    @State private var copyBadgeSize: CGSize = .zero
    let entry: Entry
    let code: Code
    let currentCode: String
    let nextCode: String
    let configuration: EntryCellConfiguration
    let issuerInfos: AuthIssuerInfo?
    let searchTerm: String
    let onCopyToken: () -> Void
    @Binding var pauseCountDown: Bool
    @Binding var copyBadgeRemainingSeconds: Int
    @Binding var animatingEntry: Entry?

    init(entry: Entry,
         code: Code,
         configuration: EntryCellConfiguration,
         issuerInfos: AuthIssuerInfo?,
         searchTerm: String,
         onCopyToken: @escaping () -> Void,
         pauseCountDown: Binding<Bool>,
         copyBadgeRemainingSeconds: Binding<Int>,
         animatingEntry: Binding<Entry?>) {
        self.entry = entry
        self.code = code
        self.configuration = configuration
        currentCode = code.displayedCode(for: .current, config: configuration)
        nextCode = code.displayedCode(for: .next, config: configuration)
        self.issuerInfos = issuerInfos
        self.searchTerm = searchTerm
        self.onCopyToken = onCopyToken
        _pauseCountDown = pauseCountDown
        _copyBadgeRemainingSeconds = copyBadgeRemainingSeconds
        _animatingEntry = animatingEntry
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            mainContent
            CopyMessageBadge(size: $copyBadgeSize)
                .opacity(showCopyBadge ? 1 : 0)
                .offset(.init(width: showCopyBadge ? 0 : copyBadgeSize.width,
                              height: -5))
        }
        .onChange(of: animatingEntry) { _, newValue in
            // Another entry is selected, we dismiss the badge of this entry
            if newValue != entry {
                withAnimation(Animation.interpolatingSpring(mass: 0.03,
                                                            stiffness: 5.5,
                                                            damping: 0.9,
                                                            initialVelocity: 4.8)) {
                    showCopyBadge = false
                }
            }
        }
        .onChange(of: copyBadgeRemainingSeconds) { _, newValue in
            if animatingEntry == entry {
                withAnimation(Animation.interpolatingSpring(mass: 0.03,
                                                            stiffness: 5.5,
                                                            damping: 0.9,
                                                            initialVelocity: 4.8)) {
                    showCopyBadge = newValue > 0
                }
            }
        }
        .onDisappear {
            // Dismiss the badge is it's still visible when the etry goes off screen
            if animatingEntry == entry {
                animatingEntry = nil
            }
        }
    }
}

private extension EntryCell {
    var mainContent: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                EntryThumbnail(iconUrl: issuerInfos?.iconUrl,
                               letter: entry.capitalLetter)

                VStack(alignment: .leading) {
                    HighlightedText(text: entry.issuer, highlighted: searchTerm)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.textNorm)
                        .textShadow()
                    HighlightedText(text: entry.name, highlighted: searchTerm)
                        .font(.system(size: 14, weight: .regular))
                        .lineLimit(1)
                        .foregroundStyle(.textWeak)
                        .textShadow()
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                TOTPCountdownView(period: entry.period,
                                  pauseCountDown: $pauseCountDown)
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
                CurrentTokenView(code: currentCode,
                                 configuration: configuration,
                                 showCopyBadge: showCopyBadge)

                Spacer()

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
                .animation(.default, value: showCopyBadge)
                .opacity(showCopyBadge ? 0 : 1)
            }
            .padding(.top, 8)
            .padding(.bottom, 12)
            .padding(.horizontal, 16)
        }
        .background(LinearGradient(stops:
            [
                .init(color: isLightMode ? .white : .white.opacity(0.11), location: 0),
                .init(color: isLightMode ? .white.opacity(0.9) : .white.opacity(0.1), location: 0.1),
                .init(color: isLightMode ? .white.opacity(0.5) : .white.opacity(0.1), location: 1)
            ],
            startPoint: UnitPoint(x: 0.5, y: 0),
            endPoint: UnitPoint(x: 0.5, y: 1)))
        .mainBackground()
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .simultaneousGesture(TapGesture().onEnded(onCopyToken))
        .overlay(entryOverlay)
        .shadow(color: .black.opacity(isLightMode ? 0.12 : 0.16),
                radius: 4,
                x: 0,
                y: isLightMode ? 3 : 2)
    }

    @ViewBuilder
    var entryOverlay: some View {
        if showCopyBadge {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.copyMessage.opacity(isLightMode ? 0.7 : 0.3),
                              lineWidth: 2)
        } else {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(LinearGradient(stops:
                    [
                        .init(color: isLightMode ? Color.white : Color(red: 0.44,
                                                                       green: 0.44,
                                                                       blue: 0.42),
                              location: 0),
                        .init(color: isLightMode ? Color.white.opacity(0.5) : Color(red: 0.31,
                                                                                    green: 0.3,
                                                                                    blue: 0.29),
                              location: 1)
                    ],
                    startPoint: UnitPoint(x: 0.5, y: 0),
                    endPoint: UnitPoint(x: 0.5, y: 1)),
                lineWidth: 0.5)
        }
    }

    var isLightMode: Bool {
        colorScheme == .light
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

    var body: some View {
        TimelineView(.animation(minimumInterval: 1, paused: pauseCountDown)) { context in
            let period = Double(period)
            let currentTimestamp = context.date.timeIntervalSince1970
            let timeRemaining = (period - currentTimestamp.truncatingRemainder(dividingBy: period)).rounded(.down)
            let progress = timeRemaining / period

            let color: Color = switch timeRemaining {
            case 0...5:
                .timer1
            case 5...10:
                .timer2
            default:
                .timer3
            }

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
                        transaction.disablesAnimations = timeRemaining == period - 1
                    }

                // Countdown text
                Text(verbatim: "\(Int(timeRemaining))")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.textNorm)
            }
            .frame(width: size, height: size)
        }
    }
}
