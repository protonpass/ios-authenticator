//
// QAMenuViewModel.swift
// Proton Authenticator - Created on 18/02/2025.
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

@_spi(QA)
import DataLayer
import FactoryKit
import Foundation

// swiftlint:disable line_length
@MainActor
@Observable
final class QAMenuViewModel {
    var installationDate: Date
    var isLoading = false

    var onboarded: Bool {
        didSet {
            appSettings.setOnboarded(onboarded)
        }
    }

    var displayPassBanner: Bool {
        didSet {
            appSettings.togglePassBanner(displayPassBanner)
        }
    }

    var fullBackupActivated: Bool {
        didSet {
            appSettings.setFullBackup(fullBackupActivated)
        }
    }

    var unsupportedScanning: Bool {
        didSet {
            appSettings.setUnsupportedScanning(unsupportedScanning)
        }
    }

    @ObservationIgnored
    private let appSettings = resolve(\ServiceContainer.settingsService)

    @ObservationIgnored
    private let keychainService = resolve(\ServiceContainer.keychainService)

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.entryDataService)
    private(set) var entryDataService

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.alertService)
    private(set) var alertService

    init() {
        installationDate = Date(timeIntervalSince1970: appSettings.installationTimestamp)
        onboarded = appSettings.onboarded
        displayPassBanner = appSettings.showPassBanner
        fullBackupActivated = appSettings.fullBackUp
        unsupportedScanning = appSettings.unsupportedScanning
    }

    func updateInstallationTimestamp(_ date: Date) {
        appSettings.setInstallationTimestamp(date.timeIntervalSince1970)
    }

    func deleteAllData() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { isLoading = false }
            isLoading = true
            do {
                try await entryDataService.deleteAll()
                alertService.showAlert(.sheet(.init(title: "Done",
                                                    titleBundle: .module,
                                                    message: .verbatim("Deleted all data"),
                                                    actions: [.ok])))
            } catch {
                alertService.showAlert(.sheet(.init(title: "An error occurred",
                                                    titleBundle: .module,
                                                    message: .verbatim(error.localizedDescription),
                                                    actions: [.ok])))
            }
        }
    }

    func deleteAllKeychainData(synchronized: Bool) {
        do {
            try keychainService.deleteAll(synchronized: synchronized)
            alertService.showAlert(.sheet(.init(title: "OK",
                                                titleBundle: .module,
                                                message: .verbatim("Keychain data deleted"),
                                                actions: [.ok])))
        } catch {
            alertService.showAlert(.sheet(.init(title: "An error occurred",
                                                titleBundle: .module,
                                                message: .verbatim("Error when deleting keychain data: \(error.localizedDescription), error: \(error)"),
                                                actions: [.ok])))
        }
    }
}

// swiftlint:enable line_length
