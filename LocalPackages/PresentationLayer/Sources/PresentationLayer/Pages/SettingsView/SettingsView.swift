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

import CommonUtilities
import Models
import SwiftUI

enum SettingsSheetStates {
    case logs
    case qa

    @MainActor @ViewBuilder
    var destination: some View {
        switch self {
        case .logs:
            LogsView()
        case .qa:
            QAMenuView()
        }
    }
}

public struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme

    @State private var viewModel = SettingsViewModel()
    @State private var router = Router()
    @State private var settingSheet: SettingsSheetStates?
    @State private var showImportOptions = false

    public init() {}

    public var body: some View {
        NavigationStack(path: $router.path) {
            List {
                if viewModel.showPassBanner {
                    PassBanner(onClose: viewModel.togglePassBanner, onGetPass: {
                        open(urlString: ProtonProduct.pass.finalUrl)
                    })
                    .padding(.horizontal, 16)
                    .buttonStyle(.plain)
                    .plainListRow()
                }
                securitySection
                appearanceSection
                dataSection
                supportSection
                if !viewModel.products.isEmpty {
                    discoverySection
                }
                versionLabel
                    .padding(.top, 32)
                    .padding(.bottom)
            }
            .animation(.default, value: viewModel.showPassBanner)
            .listStyle(.plain)
            .toolbar {
                ToolbarItem(placement: toolbarItemPlacement) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Close", bundle: .module)
                            .foregroundStyle(.purpleInteraction)
                    }
                    .adaptiveButtonStyle()
                }
            }
            .scrollContentBackground(.hidden)
            .routingProvided
            .navigationTitle(Text("Settings", bundle: .module))
            .task {
                await viewModel.setUp()
            }
            #if os(iOS)
            .listSectionSpacing(DesignConstant.padding * 2)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toastDisplay()
            .mainBackground()
            .sheetAlertService()
            .importingService($showImportOptions, onMainDisplay: false)
            .fileExporter(isPresented: $viewModel.exportedDocument.mappedToBool(),
                          document: viewModel.exportedDocument,
                          contentType: .text,
                          defaultFilename: viewModel.generateExportFileName(),
                          onCompletion: viewModel.handleExportResult)
            .sheet(isPresented: $settingSheet.mappedToBool()) {
                settingSheet?.destination
            }
        }
        .animation(.default, value: viewModel.theme)
        .preferredColorScheme(viewModel.theme.preferredColorScheme)
        #if os(macOS)
            .frame(minWidth: 800, minHeight: 600)
        #endif
    }

    private var toolbarItemPlacement: ToolbarItemPlacement {
        #if os(iOS)
        return .topBarLeading
        #else
        return .automatic
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
            SettingRow(title: .localized("Backup", .module),
                       subtitle: "Proton Authenticator will periodically save all the data to iCloud.",
                       trailingMode: .toggle(isOn: viewModel.backUpEnabled,
                                             onToggle: viewModel.toggleBackUp))

            SettingDivider()

            /*
             SettingRow(title: .localized("Sync between devices"),
                        trailingMode: .toggle(isOn: viewModel.syncEnabled,
                                              onToggle: viewModel.toggleSync))

             SettingDivider()
              */

            SettingRow(title: .localized("Biometric lock", .module),
                       trailingMode: .toggle(isOn: viewModel.biometricLock,
                                             onToggle: viewModel.toggleBioLock))

            SettingDivider()

            SettingRow(title: .localized("Hide codes", .module),
                       trailingMode: .toggle(isOn: viewModel.shouldHideCode,
                                             onToggle: viewModel.toggleHideCode))
        }
    }

    var appearanceSection: some View {
        section("APPEARANCE") {
            Menu(content: {
                ForEach(Theme.allCases, id: \.self) { theme in
                    Button(action: {
                        viewModel.updateTheme(theme)
                    }, label: {
                        if theme == viewModel.theme {
                            Label(theme.title, systemImage: "checkmark")
                        } else {
                            Text(theme.title, bundle: .module)
                        }
                    })
                }
            }, label: {
                SettingRow(title: .localized("Theme", .module),
                           trailingMode: .detailChevronUpDown(.localized(viewModel.theme.title, .module)))
            })
            .adaptiveMenuStyle()

            SettingDivider()

            Menu(content: {
                ForEach(SearchBarDisplayMode.allCases, id: \.self) { theme in
                    Button(action: {
                        viewModel.updateSearchBarDisplay(theme)
                    }, label: {
                        if theme == viewModel.searchBarDisplay {
                            Label(theme.title, systemImage: "checkmark")
                        } else {
                            Text(theme.title, bundle: .module)
                        }
                    })
                }
            }, label: {
                SettingRow(title: .localized("Search bar position", .module),
                           trailingMode: .detailChevronUpDown(.localized(viewModel.searchBarDisplay.title,
                                                                         .module)))
            })
            .adaptiveMenuStyle()

            SettingDivider()
            Menu(content: {
                ForEach(DigitStyle.allCases, id: \.self) { style in
                    Button(action: {
                        viewModel.updateDigitStyle(style)
                    }, label: {
                        if style == viewModel.digitStyle {
                            Label(style.title, systemImage: "checkmark")
                        } else {
                            Text(style.title, bundle: .module)
                        }
                    })
                }
            }, label: {
                SettingRow(title: .localized("Digit style", .module),
                           trailingMode: .detailChevronUpDown(.localized(viewModel.digitStyle.title, .module)))
            })
            .adaptiveMenuStyle()
            SettingDivider()
            SettingRow(title: .localized("Animate code change", .module),
                       trailingMode: .toggle(isOn: viewModel.animateCodeChange,
                                             onToggle: viewModel.toggleCodeAnimation))
        }
    }

    var dataSection: some View {
        section("MANAGE YOUR DATA") {
            SettingRow(title: .localized("Import", .module), onTap: { showImportOptions.toggle() })

            SettingDivider()

            SettingRow(title: .localized("Export", .module), onTap: viewModel.exportData)
        }
    }

    var supportSection: some View {
        section("SUPPORT") {
            SettingRow(title: .localized("How to use Proton Authenticator", .module))

            SettingDivider()

            SettingRow(title: .localized("Feedback", .module)) {
                open(urlString: AppConstants.CommonUrls.feedbackUrl)
            }

            SettingDivider()

            SettingRow(title: .localized("Logs", .module), onTap: { settingSheet = .logs })
        }
    }

    var discoverySection: some View {
        section("DISCOVER PROTON") {
            ForEach(viewModel.products, id: \.self) { product in
                SettingRow(icon: product.logo,
                           title: .verbatim(product.name),
                           subtitle: product.description,
                           onTap: { open(urlString: product.finalUrl) })

                if product != ProtonProduct.allCases.last {
                    SettingDivider()
                }
            }
        }
    }

    @ViewBuilder
    var versionLabel: some View {
        if let version = viewModel.versionString {
            Text(verbatim: version)
                .font(.callout)
                .foregroundStyle(.textWeak)
                .frame(maxWidth: .infinity, alignment: .center)
                .plainListRow()
                .if(viewModel.isQaBuild) { view in
                    view.onTapGesture(count: 3) {
                        settingSheet = .qa
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
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(isDarkMode ? .white.opacity(0.08) : .white)
            .cornerRadius(24)
            .overlay(RoundedRectangle(cornerRadius: 24)
                .inset(by: 0.5)
                .stroke(settingsBorder, lineWidth: 1))
        } header: {
            Text(title, bundle: .module)
                .font(.callout)
                .padding(.horizontal, DesignConstant.padding)
                .foregroundStyle(.textWeak)
        }
        .plainListRow()
        .padding(.horizontal, DesignConstant.padding)
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
        }
    }

    var description: LocalizedStringKey {
        switch self {
        case .pass:
            "Store strong, unique passwords to avoid identity theft and breaches."
        case .vpn:
            "Browse without being tracked and access blocked content."
        case .mail:
            "Protect your inbox from spam, tracking, and targeted ads."
        case .drive:
            "Organize your schedule and keep your plans to yourself."
        case .calendar:
            "Give your precious photos and files the safe home they deserve."
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

private extension Theme {
    var title: LocalizedStringKey {
        switch self {
        case .dark:
            "Dark"
        case .light:
            "Light"
        case .system:
            "Match system"
        }
    }
}
