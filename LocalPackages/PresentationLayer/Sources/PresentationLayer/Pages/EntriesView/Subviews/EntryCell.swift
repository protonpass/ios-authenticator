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

import CommonUtilities
import Models
import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

import SDWebImageSwiftUI

private struct HighlightedText: View, Equatable {
    let text: String
    let highlighted: String
    let placeholder: TextContent

    var body: some View {
        if text.isEmpty {
            Text(placeholder) // ignore:missing_bundle
                .lineLimit(1)
        } else {
            Text(attributedString) // ignore:missing_bundle
                .lineLimit(1)
        }
    }

    private var attributedString: AttributedString {
        var attributedString = AttributedString(text) // swiftlint:disable:this variable_shadowing
        var searchRange = attributedString.startIndex..<attributedString.endIndex

        while let foundRange = attributedString[searchRange].range(of: highlighted,
                                                                   options: .caseInsensitive) {
            let lowerBound = foundRange.lowerBound
            let upperBound = foundRange.upperBound

            attributedString[lowerBound..<upperBound].foregroundColor = .accentColor

            // Continue searching past this match
            searchRange = upperBound..<attributedString.endIndex
        }

        return attributedString
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.text == rhs.text && lhs.highlighted == rhs.highlighted
    }
}

struct EntryCell: View, Equatable {
    @Environment(\.colorScheme) private var colorScheme
    @State private var showCopyBadge = false
    @State private var copyBadgeSize: CGSize = .zero
    @State private var currentCodeCopy = true

    let entry: EntryUiModel
    let configuration: EntryCellConfiguration
    let searchTerm: String
    let isHovered: Bool
    let reducedShadow: Bool
    let showFavicon: Bool
    let onAction: (EntryAction) -> Void
    @Binding var animatingEntryAction: EntryAction?

    init(entry: EntryUiModel,
         configuration: EntryCellConfiguration,
         searchTerm: String,
         isHovered: Bool,
         reducedShadow: Bool,
         showFavicon: Bool,
         onAction: @escaping (EntryAction) -> Void,
         animatingEntryAction: Binding<EntryAction?>) {
        self.entry = entry
        self.configuration = configuration
        self.searchTerm = searchTerm
        self.isHovered = isHovered
        self.reducedShadow = reducedShadow
        self.showFavicon = showFavicon
        self.onAction = onAction
        _animatingEntryAction = animatingEntryAction
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if #available(iOS 26, macOS 26, *) {
                mainContent
                    .glassEffect(in: RoundedRectangle(cornerRadius: 18))
            } else {
                mainContent
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
                    .if(!reducedShadow) { view in
                        view.shadow(color: .black.opacity(isLightMode ? 0.12 : 0.16),
                                    radius: 4,
                                    x: 0,
                                    y: isLightMode ? 3 : 2)
                    }
            }

            if showCopyBadge {
                HStack {
                    if currentCodeCopy {
                        Spacer()
                    }
                    CopyMessageBadge(isCurrentCode: currentCodeCopy, size: $copyBadgeSize)
                    if !currentCodeCopy {
                        Spacer()
                    }
                }
                .id(animatingEntryAction)
                .transition(copyAnimation)
                .zIndex(1)
            }
        }
        .onChange(of: entry) { _, _ in
            animatingEntryAction = nil
        }
        .onChange(of: animatingEntryAction) { _, newValue in
            if let newValue {
                currentCodeCopy = newValue.isCurrentCodeCopyAction
            }
            withAnimation {
                showCopyBadge = newValue?.entryUiModel == entry
            }
        }
        .onDisappear {
            // Dismiss the badge is it's still visible when the etry goes off screen
            if animatingEntryAction?.entry == entry.orderedEntry.entry {
                animatingEntryAction = nil
            }
        }
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.entry == rhs.entry &&
            lhs.searchTerm == rhs.searchTerm &&
            lhs.configuration == rhs.configuration &&
            lhs.isHovered == rhs.isHovered &&
            lhs.showFavicon == rhs.showFavicon &&
            lhs.animatingEntryAction == rhs.animatingEntryAction
    }

    private var copyAnimation: AnyTransition {
        let xOffset: CGFloat = currentCodeCopy ? 100 : -100
        return .offset(x: xOffset).combined(with: .opacity)
    }
}

private extension EntryCell {
    var mainContent: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                EntryThumbnail(iconUrl: entry.issuerInfo?.iconUrl,
                               letter: entry.orderedEntry.entry.capitalLetter,
                               showFavicon: showFavicon)
                    .equatable()

                VStack(alignment: .leading) {
                    HighlightedText(text: entry.orderedEntry.entry.issuer,
                                    highlighted: searchTerm,
                                    placeholder: .localized("No issuer", .module))
                        .equatable()
                        .dynamicFont(size: 16, textStyle: .callout, weight: .medium)
                        .foregroundStyle(.textNorm)
                        .textShadow()
                    HighlightedText(text: entry.orderedEntry.entry.name,
                                    highlighted: searchTerm,
                                    placeholder: .localized("No title", .module))
                        .equatable()
                        .dynamicFont(size: 14, textStyle: .footnote)
                        .lineLimit(1)
                        .foregroundStyle(.textWeak)
                        .textShadow()
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                TOTPCountdownView(period: entry.orderedEntry.entry.period)

                if isHovered {
                    Menu(content: {
                        EntryOptions(entry: entry, onAction: { onAction($0) })
                    }, label: {
                        Image(systemName: "ellipsis.circle")
                            .dynamicFont(size: 18)
                            .foregroundStyle(.textWeak)
                    })
                }
            }
            .contentShape(.rect)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .simultaneousGesture(TapGesture().onEnded {
                onAction(.copyCurrentCode(entry))
            })

            Group {
                if #available(iOS 26, macOS 26, *) {
                    Divider()
                } else {
                    Image(.entrySeparator)
                        .resizable(resizingMode: .tile)
                        .frame(height: 2)
                        .frame(maxWidth: .infinity)
                }
            }
            .simultaneousGesture(TapGesture().onEnded {
                onAction(.copyCurrentCode(entry))
            })

            CodeView(configuration: configuration,
                     entry: entry,
                     showCopyBadge: animatingEntryAction,
                     onAction: onAction)
                .equatable()
                .padding(.top, 8)
                .padding(.bottom, 12)
                .padding(.horizontal, 16)
        }
        .animation(.linear(duration: 0.1), value: isHovered)
        .overlay(entryOverlay)
    }

    @ViewBuilder
    var entryOverlay: some View {
        if showCopyBadge,
           let isCurrentCodeCopyAction = animatingEntryAction?.isCurrentCodeCopyAction {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(isCurrentCodeCopyAction ?
                    Color.copyMessage.opacity(isLightMode ? 0.7 : 0.3) :
                    Color.purpleInteraction.opacity(isLightMode ? 0.7 : 0.3),
                    lineWidth: 2)
        } else if #unavailable(iOS 26, macOS 26) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(LinearGradient(stops:
                    [
                        .init(color: isLightMode ? Color.white : Color(red: 0.44,
                                                                       green: 0.44,
                                                                       blue: 0.42),
                              location: 0),
                        .init(color: reducedShadow ? .buttonShadowBorder :
                            (isLightMode ? Color.white.opacity(0.5) : Color(red: 0.31,
                                                                            green: 0.3,
                                                                            blue: 0.29)),
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

struct EntryOptions: View {
    let entry: EntryUiModel
    let onAction: (EntryAction) -> Void

    var body: some View {
        Button(action: { onAction(.copyCurrentCode(entry)) },
               label: { Label("Copy current code", systemImage: "square.on.square") })

        Button(action: { onAction(.copyNextCode(entry)) },
               label: { Label("Copy next code", systemImage: "square.on.square") })

        Divider()

        Button(action: { onAction(.edit(entry)) },
               label: { Label("Edit", systemImage: "pencil") })

        Divider()

        Button(role: .destructive,
               action: { onAction(.delete(entry)) },
               label: { Label("Delete", systemImage: "trash.fill") })
    }
}

private struct CodeView: View, @preconcurrency Equatable {
    let configuration: EntryCellConfiguration
    let entry: EntryUiModel
    let showCopyBadge: EntryAction?
    let onAction: (EntryAction) -> Void

    var body: some View {
        HStack(alignment: configuration.digitStyle == .boxed ? .center : .bottom, spacing: 5) {
            HStack {
                CurrentTokenView(code: entry.code.displayedCode(for: .current, config: configuration),
                                 configuration: configuration,
                                 showCopyBadge: shouldShowCopyBadge)
                    .equatable()
                Spacer()
            }
            .contentShape(.rect)
            .accessibilityAddTraits(.isButton)
            .simultaneousGesture(TapGesture().onEnded { onAction(.copyCurrentCode(entry)) })
            .opacity(codeOpacity(isCurrentCode: true))

            VStack(alignment: .trailing, spacing: 0) {
                Text("Next", bundle: .module)
                    .dynamicFont(size: 14, textStyle: .footnote)
                    .foregroundStyle(.textWeak)
                    .textShadow()
                Text(verbatim: entry.code.displayedCode(for: .next, config: configuration))
                    .dynamicFont(size: 15, textStyle: .subheadline, weight: .semibold)
                    .monospaced()
                    .foregroundStyle(nextColor)
                    .textShadow()
            }
            .opacity(codeOpacity(isCurrentCode: false))
            .accessibilityAddTraits(.isButton)
            .simultaneousGesture(TapGesture().onEnded { onAction(.copyNextCode(entry)) })
        }
        .animation(.default, value: showCopyBadge)
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.entry.code == rhs.entry.code && lhs.showCopyBadge == rhs.showCopyBadge && lhs.configuration == rhs
            .configuration
    }

    private func codeOpacity(isCurrentCode: Bool) -> Double {
        guard let showCopyBadge, showCopyBadge.entryUiModel == entry else {
            return 1
        }
        return isCurrentCode == showCopyBadge.isCurrentCodeCopyAction ? 1 : 0
    }

    private var shouldShowCopyBadge: Bool {
        guard let showCopyBadge, showCopyBadge.entryUiModel == entry else { return false }
        return true
    }

    private var nextColor: Color {
        guard let showCopyBadge, showCopyBadge.entryUiModel == entry,
              !showCopyBadge.isCurrentCodeCopyAction else { return .textNorm }
        return .purpleInteraction
    }
}

// MARK: - Circular count down display and logic

private struct TOTPCountdownView: View {
    private let period: Int
    private let size: CGFloat
    private let lineWidth: CGFloat

    init(period: Int,
         size: CGFloat = 32,
         lineWidth: CGFloat = 4) {
        self.period = period
        self.size = size
        self.lineWidth = lineWidth
    }

    var body: some View {
        TimelineView(.periodic(from: nextSecondBoundary, by: ringRefreshInterval)) { context in
            let countdown = TOTPCountdown.make(at: context.date, period: period)
            let color = color(forSecondsRemaining: countdown.secondsRemaining)

            ZStack {
                // Background circle
                Circle()
                    .stroke(lineWidth: 4)
                    .foregroundStyle(color.opacity(0.3))
                    .padding(2)
                Circle()
                    .trim(from: 1 - countdown.fractionRemaining, to: 1)
                    .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(color)
                    .padding(2)
                    .rotationEffect(.degrees(-90))

                // Countdown text
                Text(verbatim: "\(countdown.secondsRemaining)")
                    .dynamicFont(size: 12, textStyle: .caption1, weight: .semibold)
                    .foregroundStyle(.textNorm)
            }
            .frame(width: size, height: size)
        }
    }

    /// Redraw cadence for the depleting arc. The number and color only change on whole
    /// seconds; this finer interval just makes the arc sweep smoothly. Raise it to trade smoothness
    /// for energy.
    private let ringRefreshInterval: TimeInterval = 0.5

    private var nextSecondBoundary: Date {
        Date(timeIntervalSince1970: Date.now.timeIntervalSince1970.rounded(.up))
    }

    private func color(forSecondsRemaining seconds: Int) -> Color {
        switch seconds {
        case 0...5:
            .timer1

        case 6...10:
            .timer2

        default:
            .timer3
        }
    }
}
