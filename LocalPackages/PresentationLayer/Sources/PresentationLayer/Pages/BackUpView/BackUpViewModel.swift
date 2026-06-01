//
//
// BackUpViewModel.swift
// Proton Authenticator - Created on 18/07/2025.
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
import DataLayer
import DomainLayer
import FactoryKit
import Foundation
import Macro
import Models
import SimpleToast

struct PasswordProtectedBackup: Identifiable {
    let id = UUID()
    let content: String
}

@Observable
final class BackUpViewModel {
    private(set) var backups: [BackUpFileInfo] = []
    private(set) var loading = false
    private(set) var backupActivated = false

    var errorMessage: String?

    var password = ""
    var confirmedPassword = ""
    var showFolderPicker = false
    var folderDisplayName: String?
    var folderPath: String?
    var passwordProtectionFile: PasswordProtectedBackup?
    var selectedBackup: BackUpFileInfo?
    var backupToDelete: BackUpFileInfo?
    var toast: SimpleToast?

    var passwordSavable: Bool {
        !password.isEmpty && password == confirmedPassword
    }

    var showBackup: Bool {
        backupActivated && !backups.isEmpty
    }

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.backUpManager)
    private var backUpManager

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.entryDataService)
    private var entryDataService

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.keychainService)
    private var keychainService

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.alertService)
    private var alertService

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.settingsService) private var settingsService

    @ObservationIgnored
    @LazyInjected(\ToolsContainer.logManager)
    private(set) var logger

    init() {
        setUp()
    }

    func loadData() {
        guard backupActivated else {
            return
        }
        do {
            backups = try backUpManager.getAllDocumentsData()
        } catch {
            log(.error, "Failed to load backup files, error: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    func load(backup: BackUpFileInfo) {
        Task { [weak self] in
            guard let self else { return }
            var content = ""
            defer { loading = false }
            do {
                loading = true
                let data = try backUpManager.read(fileName: backup.name)
                content = String(data: data, encoding: .utf8) ?? ""
                let source = TwofaImportSource.protonAuthenticator(contents: content, password: nil)
                let numberOfImportedEntries = try await entryDataService.importEntries(from: [source])
                showCompletion(numberOfImportedEntries)
            } catch ImportException.MissingPassword {
                passwordProtectionFile = PasswordProtectedBackup(content: content)
            } catch {
                log(.error, "Failed to load backup: error: \(error.localizedDescription)")
                errorMessage = error.localizedDescription
            }
        }
    }

    func loadPasswordProtectedBackup(backup: PasswordProtectedBackup) {
        Task { [weak self] in
            guard let self else { return }
            defer {
                loading = false
                password = ""
            }
            do {
                loading = true
                let source = TwofaImportSource.protonAuthenticator(contents: backup.content,
                                                                   password: password.nilIfEmpty)
                let numberOfImportedEntries = try await entryDataService.importEntries(from: [source])
                showCompletion(numberOfImportedEntries)
            } catch ImportException.BadPassword {
                let config = AlertConfiguration(title: "Wrong password",
                                                titleBundle: .module,
                                                message: nil,
                                                actions: [.cancel])
                let alert: AlertDisplay = .sheet(config)
                alertService.showAlert(alert)
            } catch {
                log(.error, "Failed to load password protected backup: \(error.localizedDescription)")
                errorMessage = error.localizedDescription
            }
        }
    }

    func disableBackup() {
        guard backupActivated else { return }
        backUpManager.clearDestinationFolder()
        backupActivated = false
        backups = []
        folderDisplayName = nil
        folderPath = nil
    }

    func deleteBackup(_ backup: BackUpFileInfo) {
        backupToDelete = backup
    }

    func confirmDeleteBackup() {
        guard let backup = backupToDelete else { return }
        backupToDelete = nil
        do {
            try backUpManager.delete(fileName: backup.name)
            loadData()
        } catch {
            log(.error, "Failed to delete backup: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    func backup() {
        // User-driven action: bypass the dedup cache so the user always sees a fresh file written.
        let result = entryDataService.backUpEntries(force: true)
        loadData()
        switch result {
        case .notEnabled:
            break

        case .successful:
            toast = SimpleToast(title: #localized("Backup created", bundle: .module))

        case .noData:
            toast = SimpleToast(title: #localized("No data to backup", bundle: .module))

        case .unchanged:
            break

        case let .error(error):
            toast = SimpleToast(title: error.localizedDescription)
        }
    }

    func log(_ level: LogLevel, _ message: String, function: String = #function, line: Int = #line) {
        logger.log(level, category: .data, message, function: function, line: line)
    }

    func savePassword() {
        defer {
            password = ""
            confirmedPassword = ""
        }
        do {
            try keychainService.set(password,
                                    for: AppConstants.Settings.backupPassword,
                                    shouldSync: false)
            showFolderPicker = true
        } catch {
            log(.error, "Failed to save password: \(error.localizedDescription)")
        }
    }

    func handleFolderSelection(_ result: Result<URL, Error>) {
        switch result {
        case let .success(url):
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Unable to access the selected folder."
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            setBackupFolder(url)

        case let .failure(error):
            log(.error, "Folder picker failed: \(error.localizedDescription)")
        }
    }
}

private extension BackUpViewModel {
    func setUp() {
        backupActivated = settingsService.folderBackup
        guard backupActivated else { return }
        if let url = backUpManager.destinationFolderURL {
            updateFolderDisplay(from: url)
        } else {
            // The manager already toggled folderBackup off if restore failed at launch.
            backupActivated = false
        }
    }

    func updateFolderDisplay(from parentURL: URL) {
        folderDisplayName = parentURL.lastPathComponent
        folderPath = parentURL.path
    }

    func showCompletion(_ numberOfEntries: Int) {
        let hasNewEntries = numberOfEntries > 0

        let config = AlertConfiguration(title: hasNewEntries ? "Codes imported" : "No codes imported",
                                        titleBundle: .module,
                                        message: .localized(hasNewEntries ?
                                            "Successfully imported \(numberOfEntries) items" :
                                            "No new codes detected",
                                            .module),
                                        actions: [.ok])
        let alert: AlertDisplay = .sheet(config)
        alertService.showAlert(alert)
    }

    func setBackupFolder(_ folderUrl: URL) {
        do {
            try backUpManager.saveDestinationFolder(folderUrl)
            backupActivated = true
            updateFolderDisplay(from: folderUrl)

            loadData()

            if backups.isEmpty {
                // First write to a newly chosen folder must happen regardless of the cache,
                // otherwise re-selecting the same folder after emptying it would silently skip.
                entryDataService.backUpEntries(force: true)
                loadData()
            }
        } catch {
            log(.error, "Failed to set backup folder: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }
}
