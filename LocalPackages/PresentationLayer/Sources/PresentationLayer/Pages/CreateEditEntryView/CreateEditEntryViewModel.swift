//
// CreateEditEntryViewModel.swift
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

import CommonUtilities
import Factory
import Foundation
import Models

@Observable @MainActor
final class CreateEditEntryViewModel {
    var name = ""
    var secret = ""
    var issuer = ""
    var period: Int = 30
    var digits: Int = 6
    var algo: TotpAlgorithm = .sha1
    var type: TotpType = .totp
    var note = ""

    let supportedDigits: [Int] = Array(5...10)
    let supportedPeriod: [Int] = [10, 20, 30, 40, 50, 60]

    var canSave: Bool {
        secret.count >= 4 && !name.isEmpty && (type == .totp ? !issuer.isEmpty : true)
    }

    @ObservationIgnored
    @LazyInjected(\RepositoryContainer.entryRepository)
    private(set) var entryRepository

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.entryDataService)
    private(set) var entryDataService

    @ObservationIgnored
    private let entry: EntryUiModel?

    var isEditing: Bool {
        entry != nil
    }

    init(entry: EntryUiModel?) {
        self.entry = entry
        setUp(entry: entry)
    }

    func save() {
        let params: EntryParameters = if type == .totp {
            .totp(TotpParams(name: name,
                             secret: secret,
                             issuer: issuer.nilIfEmpty,
                             period: period,
                             digits: digits,
                             algorithm: algo,
                             note: note.nilIfEmpty))
        } else {
            .steam(SteamParams(name: name, secret: secret, note: note.nilIfEmpty))
        }
        Task {
            do {
                if let entry {
                    try await entryDataService.updateAndRefreshEntry(for: entry.id, with: params)
                } else {
                    try await entryDataService.insertAndRefreshEntry(from: params)
                }
            } catch {
                handle(error)
            }
        }
    }
}

private extension CreateEditEntryViewModel {
    func setUp(entry: EntryUiModel?) {
        if let entry, entry.entry.type == .totp,
           let params = try? entryRepository.getTotpParams(entry: entry.entry) {
            name = params.name
            secret = params.secret
            issuer = params.issuer ?? ""
            period = params.period ?? 30
            digits = params.digits ?? 6
            algo = params.algorithm ?? .sha1
            note = params.note ?? ""
        }
    }

    func handle(_ error: Error) {
        print(error.localizedDescription)
    }
}
