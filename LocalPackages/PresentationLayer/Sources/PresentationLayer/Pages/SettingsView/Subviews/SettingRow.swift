//
// SettingRow.swift
// Proton Authenticator - Created on 21/02/2025.
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

struct SettingRow: View {
    var icon: ImageResource?
    let title: TextContent
    var subTitleImage: Image?
    var subtitle: TextContent?
    var trailingMode: TrailingMode?
    var onTap: (() -> Void)?

    enum TrailingMode {
        case toggle(isOn: Bool, onToggle: () -> Void)
        case detailChevronRight
    }

    var body: some View {
        if let onTap {
            Button(action: onTap, label: { rowContent })
                .buttonStyle(.plain)
        } else {
            rowContent
        }
    }

    private var rowContent: some View {
        HStack(spacing: 0) {
            if let icon {
                Image(icon)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 22)
                    .padding(6)
                    .padding(.trailing, DesignConstant.padding)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title) // ignore:missing_bundle
                    .foregroundStyle(.textNorm)
                    .dynamicFont(size: 17, textStyle: .body)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

                computedSubtitle
                    .dynamicFont(size: 15, textStyle: .subheadline)
                    .foregroundStyle(.textWeak)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)

            if let trailingMode {
                Spacer()

                switch trailingMode {
                case let .toggle(isOn, onToggle):
                    StaticToggle(isOn: isOn, label: { EmptyView() }, onToggle: onToggle)
                        .fixedSize(horizontal: true, vertical: false)

                case .detailChevronRight:
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.textWeak)
                        .accessibilityHidden(true)
                }
            }
        }
        .paddingIfNotLiquidGlass()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(.rect)
    }

    @ViewBuilder
    var computedSubtitle: some View {
        if let subTitleImage, let subtitle {
            Text(subTitleImage) /* ignore:missing_bundle */ +
                Text(verbatim: " ") +
                Text(subtitle) // ignore:missing_bundle
        } else if let subtitle {
            Text(subtitle) // ignore:missing_bundle
        }
    }
}

// MARK: - Row with just a title and a trailing Menu

struct MenuSettingRow<Content: View>: View {
    let title: TextContent
    let detail: TextContent
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(spacing: 0) {
            Text(title) // ignore:missing_bundle
                .foregroundStyle(.textNorm)
                .dynamicFont(size: 17, textStyle: .body)
                .frame(maxWidth: .infinity, alignment: .leading)

            Menu(content: content, label: {
                HStack(spacing: 0) {
                    Text(detail) // ignore:missing_bundle
                        .dynamicFont(size: 17, textStyle: .body)
                        .foregroundStyle(.textWeak)
                        .padding(.trailing, DesignConstant.padding / 2)

                    Image(systemName: "chevron.up.chevron.down")
                        .foregroundStyle(.textWeak)
                        .accessibilityHidden(true)
                }
            })
            .adaptiveMenuStyle()
        }
        .paddingIfNotLiquidGlass()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Shared settings section chrome used by SettingsView and BackUpView

struct SettingsSectionContainer<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: LocalizedStringKey?
    @ViewBuilder let content: () -> Content

    private var settingsBorder: Color {
        (colorScheme == .dark ? Color.white : .black).opacity(0.12)
    }

    var body: some View {
        if #available(iOS 26, macOS 26, *) {
            Section(content: content, header: {
                if let title {
                    Text(title, bundle: .module)
                        .dynamicFont(size: 13, textStyle: .footnote)
                }
            })
        } else {
            VStack(spacing: DesignConstant.padding) {
                if let title {
                    Text(title, bundle: .module)
                        .dynamicFont(size: 13, textStyle: .footnote)
                        .foregroundStyle(.textWeak)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, DesignConstant.padding)
                }

                VStack(alignment: .leading, spacing: 0) {
                    content()
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .background(colorScheme == .dark ? .white.opacity(0.08) : .white)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .inset(by: 0.5)
                    .stroke(settingsBorder, lineWidth: 1))
            }
            .plainListRow()
            .padding(.horizontal, DesignConstant.padding)
            .padding(.top, DesignConstant.padding * 2)
        }
    }
}
