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

import Factory
import Foundation
import Macro
import Models
#if canImport(UIKit)
import UIKit
#endif

enum ExportedType {
    case data
    case logs
}

@Observable @MainActor
final class SettingsViewModel {
    private(set) var backUpEnabled = true
    private(set) var syncEnabled = false
    private(set) var products: [ProtonProduct]
    private(set) var versionString: String?
    private(set) var biometricLock = false
    var exportedDocument: TextDocument?

    @ObservationIgnored
    private var exportingType: ExportedType?

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
    @LazyInjected(\ServiceContainer.toastService)
    private var toastService

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.entryDataService)
    private(set) var entryDataService

    @ObservationIgnored
    @LazyInjected(\ToolsContainer.logManager)
    private(set) var logManager

    var theme: Theme {
        settingsService.theme
    }

    var searchBarDisplay: SearchBarDisplayMode {
        settingsService.searchBarDisplayMode
    }

    var shouldHideCode: Bool {
        settingsService.entryUIConfiguration.hideEntryCode
    }

    var showNumberBackground: Bool {
        settingsService.entryUIConfiguration.displayNumberBackground
    }

    var isQaBuild: Bool {
        bundle.isQaBuild
    }

    var showPassBanner: Bool {
        !products.contains(.pass) && settingsService.showPassBanner
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
    }
}

extension SettingsViewModel {
    func setUp() async {
        versionString = #localized("Version %@", bundle.displayedAppVersion)
    }

    func togglePassBanner() {
        settingsService.togglePassBanner(!settingsService.showPassBanner)
    }

    func toggleBackUp() {
        backUpEnabled.toggle()
    }

    // swiftlint:disable:next todo
    // TODO: use this function
    // periphery:ignore
    func toggleSync() {
        syncEnabled.toggle()
    }

    func toggleBioLock() {
        Task { [weak self] in
            guard let self else { return }
            do {
                if try await authenticateBiometrically(policy: .deviceOwnerAuthenticationWithBiometrics,
                                                       reason: #localized("Please authenticate")) {
                    biometricLock.toggle()
                    try authenticationService
                        .setAuthenticationState(biometricLock ? .active(authenticated: true) : .inactive)
                }
            } catch {
                handle(error)
            }
        }
    }

    func toggleHideCode() {
        settingsService.setHideEntryCode(!shouldHideCode)
    }

    func toggleDisplayNumberBackground() {
        settingsService.setDisplayNumberBackground(!showNumberBackground)
    }

    func updateTheme(_ newValue: Theme) {
        guard newValue != settingsService.theme else { return }
        settingsService.setTheme(newValue)
    }

    func updateSearchBarDisplay(_ newValue: SearchBarDisplayMode) {
        guard newValue != settingsService.searchBarDisplayMode else { return }
        settingsService.setSearchBarMode(newValue)
    }

    func generateExportFileName() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let currentDate = dateFormatter.string(from: .now)

        return exportingType == .logs ? "Authenticator_logs_\(currentDate).txt" :
            "Authenticator_backup_\(currentDate).txt"
    }

    func exportData() {
        do {
            exportingType = .data
            let data = try entryDataService.exportEntries()
            exportedDocument = TextDocument(data)
        } catch {
            alertService.showError(error, mainDisplay: false, action: nil)
        }
    }

    func exportLogs() {
        Task {
            do {
                let logsContent = try await logManager.logsContent()
                exportingType = .logs
                exportedDocument = TextDocument(logsContent)
            } catch {
                alertService.showError(error, mainDisplay: false, action: nil)
            }
        }
    }

    func handleExportResult(_ result: Result<URL, any Error>) {
        switch result {
        case .success:
            toastService.showToast(.init(configuration: .init(style: .init(shape: .capsule, offsetY: -30)),
                                         title: #localized("Successfully exported")))
        case let .failure(error):
            handle(error)
        }
    }
}

private extension SettingsViewModel {
    func handle(_ error: any Error) {
        logManager.log(.error, category: .ui, error.localizedDescription)
        alertService.showError(error, mainDisplay: false, action: nil)
    }
}
