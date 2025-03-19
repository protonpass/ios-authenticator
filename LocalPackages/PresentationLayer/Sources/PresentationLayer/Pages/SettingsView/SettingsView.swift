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

import Models
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme

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
                    .padding(.bottom)
            }
            .animation(.default, value: viewModel.showPassBanner)
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .routingProvided
            .navigationTitle("Settings")
            .task {
                await viewModel.setUp()
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .mainBackground()
            .toolbar {
                ToolbarItem(placement: toolbarItemPlacement) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Close")
                            .foregroundStyle(.textWeak)
                    }
                }
            }
            .sheet(isPresented: $showQaMenu) {
                QAMenuView()
            }
            .sheet(isPresented: $showEditTheme) {
                EditThemeView(currentTheme: viewModel.theme,
                              onUpdate: viewModel.updateTheme)
            }
        }
    }

    private var toolbarItemPlacement: ToolbarItemPlacement {
        #if os(iOS)
        return .topBarLeading
        #else
        return .navigation
        #endif
    }

    private var isDarkMode: Bool {
        colorScheme == .dark
    }
}

// MARK: - Sections

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
            if useMenuForTheme {
                Menu(content: {
                    ForEach(Theme.allCases, id: \.self) { theme in
                        Button(action: {
                            viewModel.updateTheme(theme)
                        }, label: {
                            if theme == viewModel.theme {
                                Label(theme.title, systemImage: "checkmark")
                            } else {
                                Text(theme.title)
                            }
                        })
                    }
                }, label: {
                    themeRow()
                })
            } else {
                themeRow {
                    showEditTheme.toggle()
                }
            }

            SettingDivider()

            Menu(content: {
                ForEach(SearchBarDisplayMode.allCases, id: \.self) { theme in
                    Button(action: {
                        viewModel.updateSearchBarDisplay(theme)
                    }, label: {
                        if theme == viewModel.searchBarDisplay {
                            Label(theme.title, systemImage: "checkmark")
                        } else {
                            Text(theme.title)
                        }
                    })
                }
            }, label: {
                SettingRow(title: .localized("Search bar position"),
                           trailingMode: .detailChevron(.localized(viewModel.searchBarDisplay.title),
                                                        onTap: {}))
            })

            SettingDivider()

            SettingRow(title: .localized("Hide cell entry code"),
                       trailingMode: .toggle(isOn: viewModel.shouldHideCode,
                                             onToggle: viewModel.toggleHideCode))
            SettingDivider()
            SettingRow(title: .localized("Show number background"),
                       trailingMode: .toggle(isOn: viewModel.showNumberBackground,
                                             onToggle: viewModel.toggleDisplayNumberBackground))
            SettingDivider()
            SettingRow(title: .localized("List style"),
                       trailingMode: .detailChevron(.verbatim("Regular"), onTap: {}))
        }
    }

    func themeRow(_ onTap: (() -> Void)? = nil) -> some View {
        SettingRow(title: .localized("Theme"),
                   trailingMode: .detailChevron(.localized(viewModel.theme.title),
                                                onTap: { onTap?() }))
    }

    var useMenuForTheme: Bool {
        #if canImport(UIKit)
        UIDevice.current.userInterfaceIdiom == .pad
        #else
        true
        #endif
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
            ForEach(ProtonProduct.allCases, id: \.self) { product in
                SettingRow(icon: product.logo,
                           title: .verbatim(product.name),
                           trailingMode: .chevron(onTap: { open(urlString: product.finalUrl) }))

                if product != ProtonProduct.allCases.last {
                    SettingDivider()
                }
            }
        }
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

    var settingsBorder: Color {
        (isDarkMode ? Color.white : .black).opacity(0.12)
    }
}

// MARK: - Utils

private extension SettingsView {
    func section(_ title: LocalizedStringKey, @ViewBuilder content: () -> some View) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(.horizontal, 0)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(isDarkMode ? .white.opacity(0.08) : .black.opacity(0.08))
            .cornerRadius(24)
            .overlay(RoundedRectangle(cornerRadius: 24)
                .inset(by: 0.5)
                .stroke(settingsBorder, lineWidth: 1))
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

private struct SettingDivider: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Rectangle()
            .foregroundStyle(.clear)
            .frame(maxWidth: .infinity, minHeight: 1, maxHeight: 1)
            .background(settingsBorder)
    }

    var settingsBorder: Color {
        (colorScheme == .dark ? Color.white : .black).opacity(0.12)
    }
}

#Preview {
    SettingsView()
}

private extension ProtonProduct {
    var logo: ImageResource {
        switch self {
        case .pass: .logoPass
        case .vpn: .logoVPN
        case .mail: .logoMail
        case .drive: .logoDrive
        case .calendar: .logoCalendar
        case .wallet: .logoWallet
        }
    }

    var finalUrl: String {
        #if os(iOS)
        iOSAppUrl
        #else
        homepageUrl
        #endif
    }
}
