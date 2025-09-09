//
//
// SettingsViewModel.swift
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

import Combine
import CommonUtilities
import DataLayer
import FactoryKit
import Foundation
import LocalAuthentication
import Macro
import Models
#if canImport(UIKit)
import SwiftUI
import UIKit
import UniformTypeIdentifiers
#endif

@Observable @MainActor
final class SettingsViewModel {
    private(set) var fullBackupEnabled = false
    private(set) var iCloudSync = true
    private(set) var syncEnabled = false
    private(set) var products: [ProtonProduct]
    private(set) var versionString: String?
    private(set) var biometricLock = false

    var settingSheet: SettingsSheet?

    var password = ""
    var confirmedPassword = ""
    var fileToExport: TextFile?

    var passwordProtectedExportable: Bool {
        !password.isEmpty && password == confirmedPassword
    }

    @ObservationIgnored
    private let bundle: Bundle

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.settingsService) private var settingsService

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.authenticationService)
    private(set) var authenticationService

    @ObservationIgnored
    @LazyInjected(\UseCaseContainer.authenticateBiometrically)
    private var authenticateBiometrically

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.alertService)
    private var alertService

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.entryDataService)
    private(set) var entryDataService

    @ObservationIgnored
    @LazyInjected(\ToolsContainer.logManager)
    private(set) var logManager

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.userSessionManager) private var userSessionManager

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.localDataManager) private var localDataManager

    #if os(iOS)
    @ObservationIgnored
    @LazyInjected(\ToolsContainer.hapticsManager)
    private(set) var hapticsManager

    @ObservationIgnored
    @LazyInjected(\ToolsContainer.mobileLoginCoordinator) private(set) var mobileLoginCoordinator
    #endif

    @ObservationIgnored
    @LazyInjected(\UseCaseContainer.openAppSettings) private var openAppSettings

    @ObservationIgnored
    @LazyInjected(\UseCaseContainer.requestForReview)
    private var requestForReview

    @ObservationIgnored
    @LazyInjected(\UseCaseContainer.emptyTempDirectory)
    private(set) var emptyTempDirectory

    @ObservationIgnored
    private var toggleBioLockTask: Task<Void, Never>?

    @ObservationIgnored
    private var toggleICloudSyncTask: Task<Void, Never>?

    @ObservationIgnored
    private var cancellables: Set<AnyCancellable> = []

    var theme: Theme {
        settingsService.theme
    }

    var searchBarDisplay: SearchBarDisplayMode {
        settingsService.searchBarDisplayMode
    }

    var shouldHideCode: Bool {
        settingsService.entryCellConfiguration.hideEntryCode
    }

    var digitStyle: DigitStyle {
        settingsService.entryCellConfiguration.digitStyle
    }

    var animateCodeChange: Bool {
        settingsService.entryCellConfiguration.animateCodeChange
    }

    // periphery:ignore
    var hapticFeedbackEnabled: Bool {
        settingsService.hapticFeedbackEnabled
    }

    var focusSearchOnLaunch: Bool {
        settingsService.focusSearchOnLaunch
    }

    var isQaBuild: Bool {
        bundle.isQaBuild
    }

    var showPassBanner: Bool {
        !products.contains(.pass) && settingsService.showPassBanner
    }

    var emailAddress: String {
        userSessionManager.userData?.user.email ?? ""
    }

    init(bundle: Bundle = .main) {
        self.bundle = bundle
        products = ProtonProduct.allCases.filter { product in
            #if canImport(UIKit)
            if let url = URL(string: "\(product.iOSAppUrlScheme)://"),
               UIApplication.shared.canOpenURL(url) {
                return false
            }
            #endif
            return true
        }
        biometricLock = authenticationService.biometricEnabled

        fullBackupEnabled = settingsService.fullBackUp

        iCloudSync = settingsService.iCloudSync

        userSessionManager.isAuthenticatedWithUserData
            .receive(on: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] authenticated in
                guard let self, authenticated != syncEnabled else { return }
                syncEnabled = authenticated
            }
            .store(in: &cancellables)
    }
}

extension SettingsViewModel {
    func setUp() async {
        versionString = #localized("Version %@", bundle: .module, bundle.displayedAppVersion)
        await requestForReview()
    }

    func getSyncMode() -> SyncMode {
        var mode: SyncMode = []
        if iCloudSync {
            mode.insert(.iCloud)
        }

        if syncEnabled {
            mode.insert(.proton)
        }

        return mode
    }

    func authenticateAndPerform(_ block: () throws -> Void) async {
        let reason = #localized("Please authenticate", bundle: .module)
        do {
            if try await authenticateBiometrically(policy: AppConstants.laEnablingPolicy,
                                                   reason: reason) {
                try block()
            }
        } catch {
            handle(error)
        }
    }

    func togglePassBanner() {
        settingsService.togglePassBanner(!settingsService.showPassBanner)
    }

    func toggleICloudSyncBackup() {
        guard toggleICloudSyncTask == nil else { return }
        toggleICloudSyncTask = Task { [weak self] in
            guard let self else { return }
            defer { toggleICloudSyncTask = nil }
            await authenticateAndPerform {
                settingsService.toggleICloudSync(!iCloudSync)
                iCloudSync.toggle()
            }
            await localDataManager.refreshLocalStorage()
        }
    }

    #if os(iOS)
    func toggleSync() {
        if !syncEnabled {
            settingSheet = .login(mobileLoginCoordinator)
        } else {
            let config = AlertConfiguration.logout {
                Task { [weak self] in
                    guard let self else { return }
                    do {
                        try await userSessionManager.logout()
                        try await entryDataService.unsyncAllEntries()
                    } catch {
                        handle(error)
                    }
                }
            }
            alertService.showAlert(.sheet(config))
        }
    }
    #endif

    func toggleBioLock() {
        guard authenticationService.canUseBiometricAuthentication() else {
            let alert = AlertDisplay.sheet(AlertConfiguration(title: "Enable biometrics",
                                                              titleBundle: .module,
                                                              // swiftlint:disable:next line_length
                                                              message: .localized("To use biometric authentication, you need to enable Face ID/Touch ID for this app in your device settings.",
                                                                                  .module),
                                                              actions: [
                                                                  .init(title: "Go to Settings",
                                                                        titleBundle: .module,
                                                                        action: { [weak self] in
                                                                            guard let self else {
                                                                                return
                                                                            }
                                                                            openAppSettings()
                                                                        }),

                                                                  .cancel
                                                              ]))
            alertService.showAlert(alert)
            return
        }
        guard toggleBioLockTask == nil else {
            return
        }
        toggleBioLockTask = Task { [weak self] in
            guard let self else { return }
            defer {
                toggleBioLockTask = nil
            }
            await authenticateAndPerform {
                biometricLock.toggle()
                try authenticationService
                    .setAuthenticationState(biometricLock ? .active(authenticated: true) : .inactive)
            }
        }
    }

    func toggleHideCode() {
        settingsService.setHideEntryCode(!shouldHideCode)
        haptic()
    }

    func updateDigitStyle(_ newValue: DigitStyle) {
        settingsService.setDigitStyle(newValue)
        haptic()
    }

    func toggleCodeAnimation() {
        settingsService.setCodeAnimation(!animateCodeChange)
        haptic()
    }

    // periphery:ignore
    func toggleHapticFeedback() {
        settingsService.toggleHapticFeedback(!hapticFeedbackEnabled)
    }

    func updateTheme(_ newValue: Theme) {
        guard newValue != settingsService.theme else { return }
        settingsService.setTheme(newValue)
    }

    func updateSearchBarDisplay(_ newValue: SearchBarDisplayMode) {
        guard newValue != settingsService.searchBarDisplayMode else { return }
        settingsService.setSearchBarMode(newValue)
        haptic()
    }

    func toggleFocusSearchOnLaunch() {
        settingsService.toggleFocusSearchOnLaunch(!focusSearchOnLaunch)
        haptic()
    }

    func exportData(shouldUsePassword: Bool = false) {
        Task { [weak self] in
            guard let self else {
                return
            }
            fileToExport = await saveToFile(shouldUsePassword: shouldUsePassword)
            password = ""
            confirmedPassword = ""
        }
    }

    func exportFileName() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let currentDate = dateFormatter.string(from: .now)

        return "Proton_Authenticator_backup_\(currentDate).json"
    }
}

private extension SettingsViewModel {
    func handle(_ error: any Error) {
        if let laError = error as? LAError, laError.code == .userCancel {
            logManager.log(.error, category: .ui, error.localizedDescription)
        } else {
            logManager.log(.error, category: .ui, error.localizedDescription)
            alertService.showError(error, mainDisplay: false, action: nil)
        }
    }

    func haptic() {
        #if os(iOS)
        hapticsManager(.defaultImpact)
        #endif
    }

    nonisolated func saveToFile(shouldUsePassword: Bool) async -> TextFile? {
        do {
            let content = try await entryDataService
                .exportEntries(password: shouldUsePassword ? password.nilIfEmpty : nil)
            return TextFile(initialText: content)
        } catch {
            if let authError = error as? AuthError,
               case let .generic(reason) = authError,
               reason.isExportEmptyData {
                return nil
            }
            await alertService.showError(error, mainDisplay: false, action: nil)
            return nil
        }
    }
}

struct TextFile: FileDocument {
    static let readableContentTypes = [UTType.plainText]

    let text: String

    init(initialText: String) {
        text = initialText
    }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            text = String(bytes: data, encoding: .utf8) ?? ""
        } else {
            text = ""
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = Data(text.utf8)
        return FileWrapper(regularFileWithContents: data)
    }
}
