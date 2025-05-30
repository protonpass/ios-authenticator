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

import AuthenticatorRustCore
import CommonUtilities
import FactoryKit
import Foundation
import Macro
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
    var shouldDismiss = false
    var errorMessage: String?

    var supportedDigits: [Int] = AppConstants.EntryOptions.supportedDigits
    var supportedPeriod: [Int] = AppConstants.EntryOptions.supportedPeriod

    var canSave: Bool {
        secret.trimmingCharacters(in: .whitespacesAndNewlines).count >= 4
            && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (type == .totp ? !issuer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty : true)
    }

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.entryDataService)
    private(set) var entryDataService

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.alertService)
    var alertService

    @ObservationIgnored
    private let entry: EntryUiModel?

    var isEditing: Bool {
        entry != nil
    }

    init(entry: EntryUiModel?) {
        self.entry = entry
        setUp(entry: entry)
    }

    func trimInputs() {
        name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        secret = secret.trimmingCharacters(in: .whitespacesAndNewlines)
        issuer = issuer.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func save() {
        trimInputs()
        guard !secret.isEmpty, !name.isEmpty else {
            return
        }

        if type == .totp, issuer.isEmpty {
            return
        }

        let params: EntryParameters = if type == .totp {
            .totp(TotpParams(name: name,
                             secret: secret,
                             issuer: issuer,
                             period: period,
                             digits: digits,
                             algorithm: algo,
                             note: note.nilIfEmpty))
        } else {
            .steam(SteamParams(name: name, secret: secret, note: note.nilIfEmpty))
        }
        Task { [weak self] in
            guard let self else { return }

            do {
                if let entry {
                    try await entryDataService.updateAndRefreshEntry(for: entry.id, with: params)
                } else {
                    try await entryDataService.insertAndRefreshEntry(from: params)
                }
                shouldDismiss = true
            } catch {
                if let error = error as? AuthenticatorRustCore.AuthenticatorError {
                    let errorMessage = error.message()
                    switch error.message() {
                    case "Unknown(\"InvalidData(Secret)\")":
                        self.errorMessage = #localized("Invalid secret", bundle: .module)
                    default:
                        self.errorMessage = errorMessage
                    }
                } else {
                    handle(error)
                }
            }
        }
    }
}

private extension CreateEditEntryViewModel {
    func setUp(entry: EntryUiModel?) {
        guard let uiEntry = entry else { return }

        switch uiEntry.orderedEntry.entry.type {
        case .steam:
            name = uiEntry.orderedEntry.entry.name
            secret = uiEntry.orderedEntry.entry.secret
            type = .steam
        case .totp:
            if let params = try? entryDataService.getTotpParams(entry: uiEntry.orderedEntry.entry) {
                name = params.name
                secret = params.secret
                issuer = params.issuer
                if let newPeriod = params.period {
                    period = newPeriod
                    supportedPeriod.appendIfNotExists(newPeriod)
                    supportedPeriod.sort()
                }

                if let newDigits = params.digits {
                    digits = newDigits
                    supportedDigits.appendIfNotExists(newDigits)
                    supportedDigits.sort()
                }
                algo = params.algorithm ?? .sha1
                note = params.note ?? ""
            }
        }
    }

    func handle(_ error: Error) {
        alertService.showError(error, mainDisplay: false, action: nil)
    }
}
