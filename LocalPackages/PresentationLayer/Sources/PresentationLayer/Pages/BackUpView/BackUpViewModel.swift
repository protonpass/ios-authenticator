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

import DataLayer
import FactoryKit
import Foundation
import Models

@Observable @MainActor
final class BackUpViewModel {
    private(set) var backups: [BackUpFileInfo] = []

    private(set) var loading = false
    var errorMessage: String?
    var backupActivated = true

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.backUpManager)
    private var backUpManager

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.entryDataService)
    private var entryDataService

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

    func loadData() async {
        do {
            backups = try await backUpManager.getAllDocumentsData()
        } catch {
            log(.error, "Failed to load backup files, error: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    func load(backup: BackUpFileInfo) {
        Task {
            defer { loading = false }
            do {
                loading = true
                let data = try await backUpManager.read(fileName: backup.name)
                let content = String(data: data, encoding: .utf8) ?? ""
                let source = TwofaImportSource.protonAuthenticator(contents: content)
                let numberOfImportedEntries = try await entryDataService.importEntries(from: [source])
                showCompletion(numberOfImportedEntries)
            } catch {
                log(.error, "Failed to load backup: \(backup), error: \(error.localizedDescription)")
                errorMessage = error.localizedDescription
            }
        }
    }

    func toggleBackICloudUp() {
        settingsService.toggleICloudBackUp(!backupActivated)
        backupActivated.toggle()
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

    func backup() {
        Task {
            do {
                guard let exportData = try entryDataService.exportEntries().data(using: .utf8) else {
                    return
                }
                try await backUpManager.write(data: exportData)
                await loadData()
            } catch {
                log(.error, "Failed to backup: \(error.localizedDescription)")
            }
        }
    }

    func log(_ level: LogLevel, _ message: String, function: String = #function, line: Int = #line) {
        logger.log(level, category: .data, message, function: function, line: line)
    }
}

private extension BackUpViewModel {
    func setUp() {
        backupActivated = settingsService.iCloudBackUp
    }
}
