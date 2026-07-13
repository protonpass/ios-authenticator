//
// DeleteAllDataViewModel.swift
// Proton Authenticator - Created on 8/09/2025.
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

import FactoryKit
import Observation

@Observable
final class DeleteAllDataViewModel {
    private(set) var state: State = .idle

    enum State: Equatable {
        case idle
        case deleting
        case deleted
        case error(any Error)

        static func == (lhs: Self, rhs: Self) -> Bool {
            switch (lhs, rhs) {
            case (.deleted, .deleted), (.deleting, .deleting), (.idle, .idle):
                true

            case let (.error(lError), .error(rError)):
                lError.localizedDescription == rError.localizedDescription

            default:
                false
            }
        }
    }

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.entryDataService)
    private(set) var entryDataService

    init() {}

    func delete() {
        guard state == .idle else { return }
        state = .deleting
        Task { [weak self] in
            guard let self else { return }
            do {
                try await entryDataService.deleteAllEntries()
                state = .deleted
            } catch {
                state = .error(error)
            }
        }
    }
}
