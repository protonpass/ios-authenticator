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
import FactoryKit
import Foundation
import Macro
import Models

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
    var showPasswordAlert = false
    var showDestinationAlert = false
    var showFolderPicker = false
    var folderDisplayName: String?
    var folderPath: String?
    var passwordProtectionFile: PasswordProtectedBackup?

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
    @ObservationIgnored
    @LazyInjected(\UseCaseContainer.authenticateBiometrically)
    private var authenticateBiometrically
    @ObservationIgnored
    private var toggleBackupTask: Task<Void, Never>?

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
        Task {
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
        Task {
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
            } catch {
                log(.error, "Failed to load password protected backup: \(error.localizedDescription)")
                errorMessage = error.localizedDescription
            }
        }
    }

    func toggleBackup() {
        guard toggleBackupTask == nil else { return }
        toggleBackupTask = Task { [weak self] in
            guard let self else { return }
            defer { toggleBackupTask = nil }
            await authenticateAndPerform {
                if backupActivated {
                    settingsService.toggleDocumentBackup(false)
                    backUpManager.clearDestinationFolder()
                    backupActivated = false
                    backups = []
                    folderDisplayName = nil
                    folderPath = nil
                } else {
                    showPasswordAlert = true
                }
            }
        }
    }

    func backup() {
        entryDataService.backUpEntries()
        loadData()
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
            showDestinationAlert = true
        } catch {
            log(.error, "Failed to save password: \(error.localizedDescription)")
        }
    }

    func changeFolder() {
        showFolderPicker = true
    }

    func useDefaultDestination() {
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory,
                                                          in: .userDomainMask).first else {
            errorMessage = "Unable to access Documents directory."
            return
        }

        let folderURL = documentsURL.appendingPathComponent(Self.defaultFolderName)

        do {
            if !FileManager.default.fileExists(atPath: folderURL.path) {
                try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
            }

            let bookmarkData = try folderURL.bookmarkData(options: [],
                                                          includingResourceValuesForKeys: nil,
                                                          relativeTo: nil)
            settingsService.setBackupFolderBookmark(bookmarkData)
            backUpManager.setDestinationFolder(folderURL)
            settingsService.toggleDocumentBackup(true)
            backupActivated = true
            updateFolderDisplay(from: folderURL)

            loadData()

            if backups.isEmpty {
                entryDataService.backUpEntries()
                loadData()
            }
        } catch {
            log(.error, "Failed to set default destination: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    func chooseCustomDestination() {
        showFolderPicker = true
    }

    func handleFolderSelection(_ result: Result<URL, Error>) {
        switch result {
        case let .success(url):
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Unable to access the selected folder."
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let bookmarkData = try url.bookmarkData(options: .minimalBookmark,
                                                        includingResourceValuesForKeys: nil,
                                                        relativeTo: nil)
                settingsService.setBackupFolderBookmark(bookmarkData)
                backUpManager.setDestinationFolder(url)
                settingsService.toggleDocumentBackup(true)
                backupActivated = true
                updateFolderDisplay(from: url)

                loadData()

                if backups.isEmpty {
                    entryDataService.backUpEntries()
                    loadData()
                }
            } catch {
                log(.error, "Failed to create bookmark: \(error.localizedDescription)")
                errorMessage = error.localizedDescription
            }

        case let .failure(error):
            log(.error, "Folder picker failed: \(error.localizedDescription)")
        }
    }
}

private extension BackUpViewModel {
    static let defaultFolderName = "Proton Authenticator Backups"

    func setUp() {
        backupActivated = settingsService.documentBackup
        if backupActivated, let bookmarkData = settingsService.backupFolderBookmark {
            do {
                let url = try backUpManager.resolveDestinationFolder(from: bookmarkData)
                updateFolderDisplay(from: url)
            } catch {
                log(.error, "Failed to resolve backup folder bookmark: \(error.localizedDescription)")
                settingsService.toggleDocumentBackup(false)
                backupActivated = false
            }
        }
    }

    func updateFolderDisplay(from url: URL) {
        folderDisplayName = url.lastPathComponent
        folderPath = url.path
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

    func authenticateAndPerform(_ block: () throws -> Void) async {
        let reason = #localized("Please authenticate", bundle: .module)
        do {
            if try await authenticateBiometrically(policy: AppConstants.laEnablingPolicy,
                                                   reason: reason) {
                try block()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
