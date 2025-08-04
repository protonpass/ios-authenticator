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
import FactoryKit
import Macro
import Models
import SwiftUI

enum SettingsSheet {
    case logs
    case qa
    #if os(iOS)
    case login(MobileCoordinatorProtocol)
    #endif

    @MainActor @ViewBuilder
    var destination: some View {
        switch self {
        case .logs:
            LogsView()
        case .qa:
            QAMenuView()
        #if os(iOS)
        case let .login(coordinator):
            UserMobileLoginController(coordinator: coordinator)
        #endif
        }
    }
}

public struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme

    @State private var viewModel = SettingsViewModel()
    @State private var router = Router()
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
            #if os(iOS)
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
                .listSectionSpacing(DesignConstant.padding * 2)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .scrollContentBackground(.hidden)
                .routingProvided
                .navigationTitle(Text("Settings", bundle: .module))
                .task {
                    await viewModel.setUp()
                }
                .toastDisplay()
                .fullScreenMainBackground()
                .sheetAlertService()
                .importingService($showImportOptions, onMainDisplay: false)
                .sheet(isPresented: $viewModel.settingSheet.mappedToBool()) {
                    viewModel.settingSheet?.destination
                }
        }
        .animation(.default, value: viewModel.theme)
        .preferredColorScheme(viewModel.theme.preferredColorScheme)
        #if os(macOS)
            .frame(minWidth: 800, minHeight: 600)
        #endif
            .onAppear {
                viewModel.exportData()
            }
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
            if viewModel.fullBackupEnabled {
                SettingRow(title: .localized("Backups", .module),
                           trailingMode: .detailChevronRight) {
                    router.navigate(to: .backup)
                }

                SettingDivider()
            } else {
                SettingRow(title: .localized("Backup", .module),
                           subtitle: .localized("Proton Authenticator will periodically save all the data to iCloud.",
                                                .module),
                           trailingMode: .toggle(isOn: viewModel.iCloudSync,
                                                 onToggle: viewModel.toggleICloudSyncBackup))
                    .toggleAccessibilityLabel(#localized("Backup", bundle: .module)
                        + ","
                        + #localized("Proton Authenticator will periodically save all the data to iCloud.",
                                     bundle: .module),
                        activateStatus(viewModel.iCloudSync))
                SettingDivider()
            }

            #if os(iOS)
            SettingRow(title: .localized("Sync between devices", .module),
                       subtitle: !viewModel.emailAddress.isEmpty ?
                           .localized("Account: \(viewModel.emailAddress)", .module) : nil,
                       trailingMode: .toggle(isOn: viewModel.syncEnabled,
                                             onToggle: viewModel.toggleSync))
                .toggleAccessibilityLabel(#localized("Sync between devices with Proton account",
                                                     bundle: .module),
                                          activateStatus(viewModel.syncEnabled))

            SettingDivider()
            #endif
            SettingRow(title: .localized("Biometric lock", .module),
                       trailingMode: .toggle(isOn: viewModel.biometricLock,
                                             onToggle: viewModel.toggleBioLock))
                .toggleAccessibilityLabel(#localized("Biometric lock", bundle: .module),
                                          activateStatus(viewModel.biometricLock))

            SettingDivider()

            SettingRow(title: .localized("Hide codes", .module),
                       trailingMode: .toggle(isOn: viewModel.shouldHideCode,
                                             onToggle: viewModel.toggleHideCode))
                .toggleAccessibilityLabel(#localized("Hide codes", bundle: .module),
                                          activateStatus(viewModel.shouldHideCode))
        }
        .onChange(of: viewModel.syncEnabled) {
            viewModel.settingSheet = nil
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
                           trailingMode: AppConstants.isIOS ?
                               .detailChevronUpDown(.localized(viewModel.theme.title, .module)) : nil)
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
                           trailingMode: AppConstants.isIOS ?
                               .detailChevronUpDown(.localized(viewModel.searchBarDisplay.title, .module)) : nil)
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
                           trailingMode: AppConstants.isIOS ?
                               .detailChevronUpDown(.localized(viewModel.digitStyle.title, .module)) : nil)
            })
            .adaptiveMenuStyle()
            SettingDivider()
            SettingRow(title: .localized("Animate code change", .module),
                       trailingMode: .toggle(isOn: viewModel.animateCodeChange,
                                             onToggle: viewModel.toggleCodeAnimation))
                .toggleAccessibilityLabel(#localized("Animate code change", bundle: .module),
                                          activateStatus(viewModel.animateCodeChange))

            #if os(iOS)
            if AppConstants.isPhone {
                SettingDivider()
                SettingRow(title: .localized("Haptic feedback", .module),
                           trailingMode: .toggle(isOn: viewModel.hapticFeedbackEnabled,
                                                 onToggle: viewModel.toggleHapticFeedback))
                    .toggleAccessibilityLabel(#localized("Haptic feedback", bundle: .module),
                                              activateStatus(viewModel.hapticFeedbackEnabled))
            }
            #endif
            SettingDivider()
            SettingRow(title: .localized("Focus search on launch", .module),
                       trailingMode: .toggle(isOn: viewModel.focusSearchOnLaunch,
                                             onToggle: viewModel.toggleFocusSearchOnLaunch))
                .toggleAccessibilityLabel(#localized("Focus search on launch", bundle: .module),
                                          activateStatus(viewModel.focusSearchOnLaunch))
        }
    }

    var dataSection: some View {
        section("MANAGE YOUR DATA") {
            SettingRow(title: .localized("Import", .module), onTap: { showImportOptions.toggle() })

            SettingDivider()

            if let exportedDocument = viewModel.shareURL {
                ShareLink(item: exportedDocument) {
                    SettingRow(title: .localized("Export", .module))
                }
                #if os(macOS)
                .offset(x: -7)
                #endif
            }
        }
    }

    var supportSection: some View {
        section("SUPPORT") {
            SettingRow(title: .localized("Feedback", .module)) {
                open(urlString: AppConstants.CommonUrls.feedbackUrl)
            }

            SettingDivider()

            SettingRow(title: .localized("Logs", .module), onTap: { viewModel.settingSheet = .logs })
        }
    }

    var discoverySection: some View {
        section("DISCOVER PROTON") {
            ForEach(viewModel.products, id: \.self) { product in
                SettingRow(icon: product.logo,
                           title: .verbatim(product.name),
                           subtitle: .localized(product.description, .module),
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
                .dynamicFont(size: 13, textStyle: .footnote)
                .foregroundStyle(.textWeak)
                .frame(maxWidth: .infinity, alignment: .center)
                .plainListRow()
                .onTapGesture(count: 3) {
                    if viewModel.isQaBuild {
                        viewModel.settingSheet = .qa
                    }
                }
        }
    }

    var settingsBorder: Color {
        (isDarkMode ? Color.white : .black).opacity(0.12)
    }

    func activateStatus(_ active: Bool) -> String {
        active ? #localized("Enabled", bundle: .module) : #localized("Disabled", bundle: .module)
    }
}

// MARK: - Utils

private extension SettingsView {
    func section(_ title: LocalizedStringKey, @ViewBuilder content: () -> some View) -> some View {
        VStack(spacing: DesignConstant.padding) {
            Text(title, bundle: .module)
                .dynamicFont(size: 13, textStyle: .footnote)
                .foregroundStyle(.textWeak)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DesignConstant.padding)

            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(isDarkMode ? .white.opacity(0.08) : .white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .inset(by: 0.5)
                .stroke(settingsBorder, lineWidth: 1))
        }
        .plainListRow()
        .padding(.horizontal, DesignConstant.padding)
        .padding(.top, DesignConstant.padding * 2)
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
            "Give your precious photos and files the safe home they deserve."
        case .calendar:
            "Organize your schedule and keep your plans to yourself."
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

private extension View {
    func toggleAccessibilityLabel(_ label: String, _ state: String) -> some View {
        accessibilityHint("You can toggle this option by clicking on the toggle button to the right of the row.")
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label + state)
    }
}
