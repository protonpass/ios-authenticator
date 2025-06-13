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
import Macro
import Models
#if canImport(UIKit)
import LocalAuthentication
import UIKit
#endif

@Observable @MainActor
final class SettingsViewModel {
    private(set) var backUpEnabled = true
    private(set) var syncEnabled = false
    private(set) var products: [ProtonProduct]
    private(set) var versionString: String?
    private(set) var biometricLock = false

    var settingSheet: SettingsSheet?

    var shareURL: URL?

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
    private var toggleBioLockTask: Task<Void, Never>?

    @ObservationIgnored
    private var toggleBackICloudUpTask: Task<Void, Never>?

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

    var displayBESync: Bool {
        settingsService.displayBESync
    }

    var emailAddress: String {
        userSessionManager.userData?.email ?? ""
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

        backUpEnabled = settingsService.iCloudBackUp

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
    }

    func togglePassBanner() {
        settingsService.togglePassBanner(!settingsService.showPassBanner)
    }

    func toggleBackICloudUp() {
        settingsService.toggleICloudBackUp(!backUpEnabled)
        backUpEnabled.toggle()
        toggleBackICloudUpTask?.cancel()
        toggleBackICloudUpTask = Task {
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
                    } catch {
                        handle(error)
                    }
                }
            }
            alertService.showAlert(.sheet(config))
        }
    }
    #endif

//    public func showError(_ error: String, mainDisplay: Bool, action: (@MainActor () -> Void)?) {
//        let config = AlertConfiguration(title: "An error occurred",
//                                        titleBundle: .module,
//                                        message: .verbatim(error),
//                                        actions: [.init(title: "OK",
//                                                        titleBundle: .module,
//                                                        role: .cancel,
//                                                        action: action)])
//        alert = mainDisplay ? .main(config) : .sheet(config)
//    }
    // }

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
                                                                        action: {
                                                                            if let settingsURL =
                                                                                URL(string: UIApplication
                                                                                    .openSettingsURLString) {
                                                                                UIApplication.shared
                                                                                    .open(settingsURL,
                                                                                          options: [:],
                                                                                          completionHandler: nil)
                                                                            }
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
            do {
                let reason = #localized("Please authenticate", bundle: .module)
                if try await authenticateBiometrically(policy: AppConstants.laEnablingPolicy,
                                                       reason: reason) {
                    biometricLock.toggle()
                    try authenticationService
                        .setAuthenticationState(biometricLock ? .active(authenticated: true) : .inactive)
                }
            } catch {
                if let laError = error as? LAError, laError.code == .userCancel {
                    logManager.log(.error, category: .ui, error.localizedDescription)
                } else {
                    handle(error)
                }
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

    func exportData() {
        do {
            let fileName = exportFileName()
            let content = try entryDataService.exportEntries()

            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            try content.write(to: tempURL, atomically: true, encoding: .utf8)
            shareURL = tempURL
        } catch {
            alertService.showError(error, mainDisplay: false, action: nil)
        }
    }
}

private extension SettingsViewModel {
    func handle(_ error: any Error) {
        logManager.log(.error, category: .ui, error.localizedDescription)
        alertService.showError(error, mainDisplay: false, action: nil)
    }

    func haptic() {
        #if os(iOS)
        hapticsManager(.defaultImpact)
        #endif
    }

    func exportFileName() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let currentDate = dateFormatter.string(from: .now)

        return "Proton_Authenticator_backup_\(currentDate).json"
    }
}
