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
import FactoryKit
import Models
import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

import SDWebImageSwiftUI

private struct HighlightedText: View, @preconcurrency Equatable {
    let text: String
    let highlighted: String
    let placeholder: TextContent

    var body: some View {
        if text.isEmpty {
            Text(placeholder) // ignore:missing_bundle
        } else {
            Text(attributedString) // ignore:missing_bundle
        }
    }

    private var attributedString: AttributedString {
        var attributedString = AttributedString(text)
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

    static func == (lhs: HighlightedText, rhs: HighlightedText) -> Bool {
        lhs.text == rhs.text && lhs.highlighted == rhs.highlighted
    }
}

struct EntryCell: View, @preconcurrency Equatable {
    @Environment(\.colorScheme) private var colorScheme
    @State private var showCopyBadge = false
    @State private var copyBadgeSize: CGSize = .zero

    let entry: EntryUiModel
    let configuration: EntryCellConfiguration
    let searchTerm: String
    let isHovered: Bool
    let reducedShadow: Bool
    let onAction: (EntryAction) -> Void
    @Binding var animatingEntry: Entry?

    init(entry: EntryUiModel,
         configuration: EntryCellConfiguration,
         searchTerm: String,
         isHovered: Bool,
         reducedShadow: Bool,
         onAction: @escaping (EntryAction) -> Void,
         animatingEntry: Binding<Entry?>) {
        self.entry = entry
        self.configuration = configuration
        self.searchTerm = searchTerm
        self.isHovered = isHovered
        self.reducedShadow = reducedShadow
        self.onAction = onAction
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
            withAnimation(Animation.interpolatingSpring(mass: 0.03,
                                                        stiffness: 5.5,
                                                        damping: 0.9,
                                                        initialVelocity: 4.8)) {
                showCopyBadge = newValue == entry.orderedEntry.entry
            }
        }
        .onDisappear {
            // Dismiss the badge is it's still visible when the etry goes off screen
            if animatingEntry == entry.orderedEntry.entry {
                animatingEntry = nil
            }
        }
    }

    static func == (lhs: EntryCell, rhs: EntryCell) -> Bool {
        lhs.entry == rhs.entry &&
            lhs.searchTerm == rhs.searchTerm &&
            lhs.configuration == rhs.configuration &&
            lhs.isHovered == rhs.isHovered &&
            lhs.animatingEntry == rhs.animatingEntry
    }
}

private extension EntryCell {
    var mainContent: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                EntryThumbnail(iconUrl: entry.issuerInfo?.iconUrl,
                               letter: entry.orderedEntry.entry.capitalLetter)
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
            .padding(.vertical, 12)
            .padding(.horizontal, 16)

            Image(.entrySeparator)
                .resizable(resizingMode: .tile)
                .frame(height: 2)
                .frame(maxWidth: .infinity)

            CodeView(configuration: configuration, code: entry.code, showCopyBadge: showCopyBadge)
                .equatable()
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
        .animation(.linear(duration: 0.1), value: isHovered)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .simultaneousGesture(TapGesture().onEnded { onAction(.copyCurrentCode(entry)) })
        .overlay(entryOverlay)
        .if(!reducedShadow) { view in
            view.shadow(color: .black.opacity(isLightMode ? 0.12 : 0.16),
                        radius: 4,
                        x: 0,
                        y: isLightMode ? 3 : 2)
        }
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
    let code: Code
    let showCopyBadge: Bool

    var body: some View {
        HStack(alignment: configuration.digitStyle == .boxed ? .center : .bottom) {
            CurrentTokenView(code: code.displayedCode(for: .current, config: configuration),
                             configuration: configuration,
                             showCopyBadge: showCopyBadge)
                .equatable()

            Spacer()

            VStack(alignment: .trailing, spacing: 0) {
                Text("Next", bundle: .module)
                    .dynamicFont(size: 14, textStyle: .footnote)
                    .foregroundStyle(.textWeak)
                    .textShadow()
                Text(verbatim: code.displayedCode(for: .next, config: configuration))
                    .dynamicFont(size: 15, textStyle: .subheadline, weight: .semibold)
                    .monospaced()
                    .foregroundStyle(.textNorm)
                    .textShadow()
                    .privacySensitive()
            }
            .animation(.default, value: showCopyBadge)
            .opacity(showCopyBadge ? 0 : 1)
        }
    }

    static func == (lhs: CodeView, rhs: CodeView) -> Bool {
        lhs.code == rhs.code && lhs.showCopyBadge == rhs.showCopyBadge && lhs.configuration == rhs.configuration
    }
}

// MARK: - Circular count down display and logic

private struct TOTPCountdownView: View {
    private let period: Int
    private let size: CGFloat
    private let lineWidth: CGFloat

    @State private var timerManager = resolve(\ServiceContainer.totpCountdownManager)

    init(period: Int,
         size: CGFloat = 32,
         lineWidth: CGFloat = 4) {
        self.period = period
        self.size = size
        self.lineWidth = lineWidth
    }

    var body: some View {
        let infos = timerManager.calculateCountdownInfo(period: period)

        ZStack {
            // Background circle
            Circle()
                .stroke(lineWidth: 4)
                .foregroundStyle(infos.color.opacity(0.3))
                .padding(2)

            // Progress circle
            Circle()
                .trim(from: 1 - infos.progress, to: 1)
                .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                .foregroundStyle(infos.color)
                .padding(2)
                .rotationEffect(.degrees(-90))
                .if(AppConstants.isPhone) { view in
                    view.animation(.default, value: infos.progress)
                        .transaction { transaction in
                            transaction.disablesAnimations = infos.timeRemaining == Int(Double(period) - 1)
                        }
                }

            // Countdown text
            Text(verbatim: "\(infos.timeRemaining)")
                .dynamicFont(size: 12, textStyle: .caption1, weight: .semibold)
                .foregroundStyle(.textNorm)
        }
        .frame(width: size, height: size)
    }
}
