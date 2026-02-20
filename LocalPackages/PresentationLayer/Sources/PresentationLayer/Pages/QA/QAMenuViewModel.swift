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
import Models

struct KeychainContent: Identifiable {
    let id: String
    let content: [String: Any]

    var key: String {
        content["key"] as? String ?? ""
    }
}

struct EntryContent: Identifiable {
    let id: String = UUID().uuidString
    let numberOfDecryptedEntries: Int
    let numberOfUnDecryptableEntries: Int
}

// swiftlint:disable line_length
@Observable
final class QAMenuViewModel {
    var installationDate: Date
    var isLoading = false
    var keychainContent = [KeychainContent]()
    var entriesContent: EntryContent?

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

//    var fullBackupActivated: Bool {
//        didSet {
//            appSettings.setFullBackup(fullBackupActivated)
//        }
//    }

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
    @LazyInjected(\ServiceContainer.alertService)
    private(set) var alertService

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.backUpManager)
    private var backUpManager

    @ObservationIgnored
    @LazyInjected(\ToolsContainer.logManager)
    private(set) var logManager

    @ObservationIgnored
    @LazyInjected(\RepositoryContainer.entryRepository)
    private(set) var entryRepository

    init() {
        installationDate = Date(timeIntervalSince1970: appSettings.installationTimestamp)
        onboarded = appSettings.onboarded
        displayPassBanner = appSettings.showPassBanner
//        fullBackupActivated = appSettings.fullBackUp
        unsupportedScanning = appSettings.unsupportedScanning
        loadKeychainContent()
        loadEntryContent()
    }

    func updateInstallationTimestamp(_ date: Date) {
        appSettings.setInstallationTimestamp(date.timeIntervalSince1970)
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

    func deleteAllKeychainData() {
        do {
            try keychainService.deleteAll(synchronized: true)
            try keychainService.deleteAll(synchronized: false)
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

    func deleteAllLogs() {
        Task {
            do {
                try await logManager.deleteAllLogs()
                alertService.showAlert(.sheet(.init(title: "OK",
                                                    titleBundle: .module,
                                                    message: .verbatim("Logs were deleted"),
                                                    actions: [.ok])))
            } catch {
                alertService.showAlert(.sheet(.init(title: "An error occurred",
                                                    titleBundle: .module,
                                                    message: .verbatim("Error when deleting logs: \(error.localizedDescription), error: \(error)"),
                                                    actions: [.ok])))
            }
        }
    }

    func deleteAll() {
        try? backUpManager.deleteAllBackupFiles()
    }

    func loadKeychainContent() {
        keychainContent = keychainService.getAllContent().map { element in KeychainContent(id: UUID().uuidString,
                                                                                           content: element) }
    }

    func loadEntryContent() {
        Task {
            guard let content = try? await entryRepository.getAllLocalEntries() else {
                return
            }
            let nonDecryptableEntries = content.filter(\.isNonDecryptable).count
            let decryptableEntries = content.count(where: { !$0.isNonDecryptable })
            entriesContent = EntryContent(numberOfDecryptedEntries: decryptableEntries,
                                          numberOfUnDecryptableEntries: nonDecryptableEntries)
        }
    }
}

// swiftlint:enable line_length
