//
// DuplicateEntriesViewModel.swift
// Proton Authenticator - Created on 25/02/2026.
// Copyright (c) 2026 Proton Technologies AG
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

import DataLayer
import FactoryKit
import Foundation

@Observable
final class DuplicateEntriesViewModel {
    private(set) var groups: [DuplicateEntryGroup] = []
    private(set) var loading = false
    var errorMessage: String?

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.entryDataService)
    private var entryDataService

    @ObservationIgnored
    @LazyInjected(\ToolsContainer.logManager)
    private var logger

    @ObservationIgnored
    let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    func loadGroups() async {
        loading = true
        defer { loading = false }
        await entryDataService.loadDuplicateGroups()
        groups = entryDataService.duplicateGroups
    }

    func delete(entryId: String, modifiedTime: TimeInterval) {
        Task { [weak self] in
            guard let self else { return }
            loading = true
            defer { loading = false }
            do {
                try await entryDataService.deleteDuplicate(entryId: entryId, modifiedTime: modifiedTime)
                groups = entryDataService.duplicateGroups
            } catch {
                logger.log(.error, category: .data, error.localizedDescription)
                errorMessage = error.localizedDescription
            }
        }
    }
}
