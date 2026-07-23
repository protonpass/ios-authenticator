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
import StoreKit
import SwiftUI
import UniformTypeIdentifiers

enum SettingsSheet {
    case logs
    case qa
    #if os(iOS)
    case login(MobileCoordinatorProtocol)
    #endif

    @ViewBuilder
    var destination: some View {
        switch self {
        case .logs:
            LogsView()

        case .qa:
            QAMenuView()

        #if os(iOS)
        case let .login(coordinator):
            UserMobileLoginController(coordinator: coordinator)
                .ignoresSafeArea()
        #endif
        }
    }
}

public struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var viewModel = SettingsViewModel()
    @State private var router = Router()
    @State private var showImportOptions = false
    @State private var showExportAlert = false
    @State private var showPasswordExportAlert = false
    @State private var showDeleteAllDataSheet = false

    public init() {}

    public var body: some View {
        NavigationStack(path: $router.path) {
            List {
                if viewModel.showPassBanner {
                    PassBanner(onClose: viewModel.togglePassBanner, onGetPass: {
                        open(urlString: ProtonProduct.pass.finalUrl)
                    })
                    .ifNoLiquidGlass { view in
                        view.padding(.horizontal, 16)
                    }
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

                ratingSection

                deleteAllDataButton
                    .ifNoLiquidGlass { view in
                        view.padding(.vertical, 32)
                    }
                versionLabel
                    .padding(.bottom)
            }
            .animation(.default, value: viewModel.showPassBanner)
            .settingsListStyle()
            #if os(iOS)
                .toolbar {
                    ToolbarItem(placement: toolbarItemPlacement) {
                        Button {
                            dismiss()
                        } label: {
                            if #available(iOS 26, macOS 26, *) {
                                Image(systemName: "xmark")
                                    .accessibility(label: Text("Close", bundle: .module))
                            } else {
                                Text("Close", bundle: .module)
                                    .foregroundStyle(.purpleInteraction)
                                    .adaptiveButtonStyle()
                            }
                        }
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
                .fullScreenMainBackground()
                .sheetAlertService()
                .importingService($showImportOptions, context: .settings)
                .sheet(isPresented: $viewModel.settingSheet.mappedToBool()) {
                    viewModel.settingSheet?.destination
                }
        }
        .animation(.default, value: viewModel.theme)
        .preferredColorScheme(viewModel.theme.preferredColorScheme)
        .alert("Export data", isPresented: $showExportAlert) {
            Button { showPasswordExportAlert.toggle() } label: {
                Text("Password protected", bundle: .module)
            }
            Button { viewModel.exportData(shouldUsePassword: false) } label: {
                Text("Plain text", bundle: .module)
            }

            Button("Cancel", role: .cancel) {}
        }
        .alert("Export data",
               isPresented: $showPasswordExportAlert,
               actions: {
                   SecureField("Password", text: $viewModel.password)
                       .autocorrectionDisabled()
                       .textContentType(.password)
                       .textInputAutocapitalization(.never)
                   SecureField("Confirm password", text: $viewModel.confirmedPassword)
                       .autocorrectionDisabled()
                       .textContentType(.password)
                       .textInputAutocapitalization(.never)

                   Button { viewModel.exportData(shouldUsePassword: true) } label: {
                       Text("Export", bundle: .module)
                   }
                   .disabled(!viewModel.passwordProtectedExportable)

                   Button("Cancel", role: .cancel) {
                       viewModel.password = ""
                       viewModel.confirmedPassword = ""
                   }
               }, message: {
                   Text("Set a password to protect the export file.", bundle: .module)
               })
        .sheet(isPresented: $showDeleteAllDataSheet) {
            DeleteAllDataView(mode: viewModel.getSyncMode())
                .interactiveDismissDisabled()
        }
        #if os(macOS)
        .frame(minWidth: 800, minHeight: 600)
        #endif
        .onDisappear {
            viewModel.emptyTempDirectory()
        }
        .fileExporter(isPresented: $viewModel.fileToExport.mappedToBool(),
                      document: viewModel.fileToExport,
                      contentTypes: [.plainText],
                      defaultFilename: viewModel.exportFileName()) { result in
            switch result {
            case let .success(url):
                viewModel.logManager.log(.info, category: .ui, "File exported to \(url)")

            case let .failure(error):
                viewModel.logManager.log(.error,
                                         category: .ui,
                                         "File export failed: \(error.localizedDescription)")
            }
        }
    }

    private var toolbarItemPlacement: ToolbarItemPlacement {
        #if os(iOS)
        return .topBarLeading
        #else
        return .automatic
        #endif
    }
}

// MARK: - Sections

private extension SettingsView {
    var securitySection: some View {
        SettingsSectionContainer(title: "SECURITY") {
            SettingRow(title: .localized("Backups", .module),
                       trailingMode: .detailChevronRight) {
                router.navigate(to: .backup)
            }

            SettingDivider()

            #if os(iOS)
            SettingRow(title: .localized("Sync via Proton", .module),
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

            if #available(iOS 18, *) {
                SettingDivider()
                SettingRow(title: .localized("iCloud sync", .module),
                           config: SettingRowConfig(titleColor: .textWeak),
                           trailingMode: .detailChevronRight) {
                    router.navigate(to: .iCloudSync)
                }
            }
        }
        .onChange(of: viewModel.syncEnabled) {
            viewModel.settingSheet = nil
        }
    }

    var appearanceSection: some View {
        SettingsSectionContainer(title: "APPEARANCE") {
            MenuSettingRow(title: .localized("Theme", .module),
                           detail: .localized(viewModel.theme.title, .module)) {
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
            }

            SettingDivider()

            if AppConstants.adjustableSearchBarPosition {
                MenuSettingRow(title: .localized("Search bar position", .module),
                               detail: .localized(viewModel.searchBarDisplay.title, .module)) {
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
                }

                SettingDivider()
            }

            MenuSettingRow(title: .localized("Digit style", .module),
                           detail: .localized(viewModel.digitStyle.title, .module)) {
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
            }
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
        SettingsSectionContainer(title: "MANAGE YOUR DATA") {
            SettingRow(title: .localized("Import", .module), onTap: { showImportOptions.toggle() })

            SettingDivider()

            Button { showExportAlert.toggle() } label: {
                SettingRow(title: .localized("Export", .module))
            }
        }
    }

    var supportSection: some View {
        SettingsSectionContainer(title: "SUPPORT") {
            SettingRow(title: .localized("Report an issue", .module)) {
                open(urlString: AppConstants.CommonUrls.feedbackUrl)
            }

            SettingDivider()

            SettingRow(title: .localized("Logs", .module), onTap: { viewModel.settingSheet = .logs })
        }
    }

    var discoverySection: some View {
        SettingsSectionContainer(title: "DISCOVER PROTON") {
            ForEach(viewModel.products, id: \.self) { product in
                SettingRow(icon: .resource(product.logo),
                           title: .verbatim(product.name),
                           subtitle: .localized(product.description, .module),
                           onTap: { open(urlString: product.finalUrl) })

                if product != ProtonProduct.allCases.last {
                    SettingDivider()
                }
            }
        }
    }

    // swiftlint:disable line_length
    var ratingSection: some View {
        SettingsSectionContainer(title: "SPREAD THE WORD") {
            if let url = AppConstants.AppStoreLink.url {
                ShareLink(item: url,
                          subject: Text("The app that keeps your accounts safe"),
                          message: Text("Hey there! I use this Authenticator app to protect my accounts from getting hacked. Really easy to set up. You should grab it too :)")) {
                    SettingRow(icon: .resource(.appInfoSent),
                               title: .localized("Tell a friend", .module),
                               trailingMode: .detailChevronRight)
                }
                .buttonStyle(.plain)

                SettingDivider()
            }

            SettingRow(icon: .resource(.appStarRating),
                       title: .localized("Rate Proton Authenticator", .module),
                       trailingMode: .detailChevronRight) {
                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    AppStore.requestReview(in: scene)
                }
            }
        }
    }

    // swiftlint:enable line_length

    var deleteAllDataButton: some View {
        Button(action: {
                   Task {
                       await viewModel.authenticateAndPerform {
                           showDeleteAllDataSheet.toggle()
                       }
                   }
               },
               label: {
                   Text("Delete all data", bundle: .module)
                       .fontWeight(.semibold)
                       .foregroundStyle(.error)
                       .frame(maxWidth: .infinity, alignment: .center)
               })
               .padding(DesignConstant.padding)
               .background(.clear)
               .buttonStyle(.plain)
               .plainListRow()
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

    func activateStatus(_ active: Bool) -> String {
        active ? #localized("Enabled", bundle: .module) : #localized("Disabled", bundle: .module)
    }
}

// MARK: - Utils

private extension SettingsView {
    func open(urlString: String) {
        if let url = URL(string: urlString) {
            openURL(url)
        }
    }
}

struct SettingDivider: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        // We use default grouped list for iOS 26+ which renders dividers automatically
        if #unavailable(iOS 26, macOS 26) {
            Rectangle()
                .foregroundStyle(.clear)
                .frame(maxWidth: .infinity, minHeight: 1, maxHeight: 1)
                .background(settingsBorder)
        }
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
    @ViewBuilder
    func settingsListStyle() -> some View {
        if #available(iOS 26, macOS 26, *) {
            listStyle(.insetGrouped)
        } else {
            listStyle(.plain)
        }
    }
}

enum Icon: Hashable, Sendable {
    case system(String) // SF Symbol, e.g. "paperplane"
    case resource(ImageResource) // asset-catalog image or symbol image set

    var image: Image {
        switch self {
        case let .system(name): Image(systemName: name)
        case let .resource(res): Image(res)
        }
    }
}
