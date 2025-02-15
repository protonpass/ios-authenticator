//
// SettingsView.swift
// Proton Authenticator - Created on 10/02/2025.
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

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var viewModel = SettingsViewModel()
    @State private var router = Router()
    @State private var showQaMenu = false
    @State private var showEditTheme = false

    var body: some View {
        NavigationStack(path: $router.path) {
            List {
                if viewModel.showPassBanner {
                    PassBanner(onClose: viewModel.togglePassBanner, onGetPass: {})
                        .padding(.horizontal, 16)
                        .buttonStyle(.plain)
                        .plainListRow()
                }
                securitySection
                appearanceSection
                dataSection
                supportSection
                discoverySection
                versionLabel
                    .padding(.top, 32)
            }
            .animation(.default, value: viewModel.showPassBanner)
            .listStyle(.plain)
            .routingProvided
            .navigationTitle("Settings")
            .task {
                await viewModel.setUp()
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .background(.backgroundGradient)
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Close")
                            .foregroundStyle(.textWeak)
                    }
                }
                #elseif os(macOS)
                ToolbarItem(placement: .navigation) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Close")
                            .foregroundStyle(.textWeak)
                    }
                }
                #endif
            }
            #if os(iOS)
            .toolbarColorScheme(.dark, for: .navigationBar, .tabBar)
            .toolbarBackground(.gradientStart, for: .navigationBar, .tabBar)
            .toolbarBackground(.visible, for: .navigationBar, .tabBar)
            #endif
            .accentColor(.gradientStart)
            .sheet(isPresented: $showQaMenu) {
                QAMeuView()
            }
            .sheet(isPresented: $showEditTheme) {
                EditThemeView(currentTheme: viewModel.theme,
                              onUpdate: viewModel.updateTheme)
            }
        }
    }
}

private extension SettingsView {
    var securitySection: some View {
        section("SECURITY") {
            SettingRow(title: .localized("Backup"),
                       subtitle: "Proton Authenticator will periodically save all the data to iCloud.",
                       trailingMode: .toggle(isOn: viewModel.backUpEnabled,
                                             onToggle: viewModel.toggleBackUp))

            SettingDivider()

            SettingRow(title: .localized("Sync between devices"),
                       trailingMode: .toggle(isOn: viewModel.syncEnabled,
                                             onToggle: viewModel.toggleSync))

            SettingDivider()

            SettingRow(title: .localized("App lock"),
                       trailingMode: .detailChevron(.verbatim("Face ID"), onTap: {}))

            SettingDivider()

            SettingRow(title: .localized("Tap to reveal codes"),
                       trailingMode: .toggle(isOn: viewModel.tapToRevealCodeEnabled,
                                             onToggle: viewModel.toggleTapToRevealCode))
        }
    }

    var appearanceSection: some View {
        section("APPEARANCE") {
            SettingRow(title: .localized("Theme"),
                       trailingMode: .detailChevron(.localized(viewModel.theme.title),
                                                    onTap: { showEditTheme.toggle() }))

            SettingDivider()

            SettingRow(title: .localized("List style"),
                       trailingMode: .detailChevron(.verbatim("Regular"), onTap: {}))
        }
    }

    var dataSection: some View {
        section("MANAGE YOUR DATA") {
            SettingRow(title: .localized("Import"), trailingMode: .chevron(onTap: {}))

            SettingDivider()

            SettingRow(title: .localized("Export"), trailingMode: .chevron(onTap: {}))
        }
    }

    var supportSection: some View {
        section("SUPPORT") {
            SettingRow(title: .localized("How to use Proton Authenticator"),
                       trailingMode: .chevron(onTap: {}))

            SettingDivider()

            SettingRow(title: .localized("Feedback"), trailingMode: .chevron(onTap: {}))
        }
    }

    var discoverySection: some View {
        section("DISCOVER PROTON") {
            productRow("Proton Pass", logoName: "logoPass", path: "pass")
            SettingDivider()
            productRow("Proton VPN", logoName: "logoVPN", path: "vpn")
            SettingDivider()
            productRow("Proton Mail", logoName: "logoMail", path: "mail")
            SettingDivider()
            productRow("Proton Drive", logoName: "logoDrive", path: "drive")
            SettingDivider()
            productRow("Proton Calendar", logoName: "logoCalendar", path: "calendar")
            SettingDivider()
            productRow("Proton Wallet", logoName: "logoWallet", path: "wallet")
        }
    }

    func productRow(_ name: String, logoName: String, path: String) -> some View {
        SettingRow(icon: ImageResource(name: logoName, bundle: .module),
                   title: .verbatim(name),
                   trailingMode: .chevron(onTap: { open(urlString: "https://proton.me/\(path)") }))
    }

    @ViewBuilder
    var versionLabel: some View {
        if let version = viewModel.versionString {
            Text(version)
                .font(.callout)
                .foregroundStyle(.textWeak)
                .frame(maxWidth: .infinity, alignment: .center)
                .plainListRow()
                .if(viewModel.isQaBuild) { view in
                    view.onTapGesture(count: 3) {
                        showQaMenu.toggle()
                    }
                }
        }
    }

    func section(_ title: LocalizedStringKey, @ViewBuilder content: () -> some View) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(.horizontal, 0)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(.white.opacity(0.08))
            .cornerRadius(24)
            .overlay(RoundedRectangle(cornerRadius: 24)
                .inset(by: 0.5)
                .stroke(Color.settingsBorder, lineWidth: 1))
            .padding(.top, 8)
        } header: {
            Text(title)
                .font(.callout)
                .padding(.leading)
                .foregroundStyle(.textWeak)
        }
        .plainListRow()
        .padding(.horizontal, 16)
    }

    func open(urlString: String) {
        if let url = URL(string: urlString) {
            openURL(url)
        }
    }
}

private extension Color {
    static var settingsBorder: Color {
        .white.opacity(0.12)
    }
}

private struct SettingDivider: View {
    var body: some View {
        Rectangle()
            .foregroundStyle(.clear)
            .frame(maxWidth: .infinity, minHeight: 1, maxHeight: 1)
            .background(Color.settingsBorder)
    }
}

#Preview {
    SettingsView()
}

private struct SettingRow: View {
    var icon: ImageResource?
    let title: TextContent
    var subtitle: LocalizedStringKey?
    let trailingMode: TrailingMode

    enum TrailingMode {
        case toggle(isOn: Bool, onToggle: () -> Void)
        case chevron(onTap: () -> Void)
        case detailChevron(TextContent, onTap: () -> Void)

        var onTap: (() -> Void)? {
            switch self {
            case let .chevron(onTap):
                onTap
            case let .detailChevron(_, onTap):
                onTap
            default:
                nil
            }
        }
    }

    var body: some View {
        HStack {
            if let icon {
                Image(icon)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 24)
            }

            VStack(alignment: .leading) {
                Text(title)
                    .foregroundStyle(.textNorm)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

                if let subtitle {
                    Text(subtitle)
                        .font(.callout)
                        .foregroundStyle(.textWeak)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)

            Spacer()

            switch trailingMode {
            case let .toggle(isOn, onToggle):
                StaticToggle(isOn: isOn, label: { EmptyView() }, onToggle: onToggle)

            case .chevron:
                Image(systemName: "chevron.right")
                    .foregroundStyle(.textWeak)

            case let .detailChevron(detail, _):
                Text(detail)
                    .foregroundStyle(.textNorm)

                Image(systemName: "chevron.right")
                    .foregroundStyle(.textWeak)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(.rect)
        .if(trailingMode.onTap) { view, onTap in
            view.onTapGesture(perform: onTap)
        }
    }
}
