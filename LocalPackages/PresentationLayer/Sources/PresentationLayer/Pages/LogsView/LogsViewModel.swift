//
//
// LogsViewModel.swift
// Proton Authenticator - Created on 16/04/2025.
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
import Factory
import Foundation
import Macro
import Models

@Observable @MainActor
final class LogsViewModel {
    private(set) var logs: [LogEntry] = []
    var exportedDocument: TextDocument?

    @ObservationIgnored
    @LazyInjected(\ToolsContainer.logManager)
    private(set) var logManager

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.alertService)
    private var alertService

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.toastService)
    private var toastService

    init() {
        setUp()
    }

    func exportLogs() {
        Task { [weak self] in
            guard let self else { return }
            do {
                let logsContent = try await logManager.logsContent()
                exportedDocument = TextDocument(logsContent)
            } catch {
                alertService.showError(error, mainDisplay: false, action: nil)
            }
        }
    }

    func generateExportFileName() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let currentDate = dateFormatter.string(from: .now)

        return "Authenticator_logs_\(currentDate).txt"
    }

    func handleExportResult(_ result: Result<URL, any Error>) {
        switch result {
        case .success:
            toastService.showToast(.init(configuration: .init(style: .init(shape: .capsule, offsetY: -30)),
                                         title: #localized("Successfully exported", bundle: .module)))
        case let .failure(error):
            alertService.showError(error, mainDisplay: false, action: nil)
        }
    }
}

private extension LogsViewModel {
    func setUp() {
        Task { [weak self] in
            guard let self else { return }
            do {
                logs = try await logManager.fetchLogs()
            } catch {
                alertService.showError(error, mainDisplay: false, action: nil)
            }
        }
    }
}
