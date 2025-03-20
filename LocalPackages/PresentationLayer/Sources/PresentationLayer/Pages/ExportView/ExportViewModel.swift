//
//
// ExportViewModel.swift
// Proton Authenticator - Created on 20/03/2025.
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
import Models

@Observable @MainActor
final class ExportViewModel {
    private(set) var backup: TextDocument?
    var showingExporter = false

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.entryDataService)
    private(set) var entryDataService

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.alertService)
    private var alertService

    @ObservationIgnored
    private let currentDate: String

    var backupTitle: String {
        "Authenticator_backup_\(currentDate).txt"
    }

    init() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let date = Date()
        currentDate = dateFormatter.string(from: date)
        setUp()
    }

    func createBackup() {
        do {
            guard let data = try entryDataService.exportEntries() else {
                return
            }
            backup = TextDocument(data)
            showingExporter = true
        } catch {
            alertService.showError(error, mainDisplay: false, action: nil)
        }
    }

    func parseExport(result: Result<URL, any Error>) {
        switch result {
        case let .success(url):
            // TODO: toast complemted and dismiss
            print("Saved to \(url)")
        case let .failure(error):
            alertService.showError(error, mainDisplay: false, action: nil)
        }
    }
}

private extension ExportViewModel {
    func setUp() {}
}
