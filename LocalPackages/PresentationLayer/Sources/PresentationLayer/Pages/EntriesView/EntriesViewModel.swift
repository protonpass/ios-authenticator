//
// EntriesViewModel.swift
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

import Combine
import Factory
import Foundation
import Models

@Observable
@MainActor
final class EntriesViewModel {
    var entries: [EntryUiModel] {
        (qaService.showMockEntries ? qaService.dataState.data : entryDataService.dataState.data) ?? []
    }

    var dataState: DataState<[EntryUiModel]> {
        qaService.showMockEntries ? qaService.dataState : entryDataService.dataState
    }

    var search = ""

    @ObservationIgnored
    private var pauseRefreshing = false

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.qaService)
    private var qaService

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.entryDataService)
    private(set) var entryDataService

    @ObservationIgnored
    @LazyInjected(\UseCaseContainer.copyTextToClipboard)
    private var copyTextToClipboard

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.alertService)
    private var alertService

    @ObservationIgnored
    private var cancellable: (any Cancellable)?

    @ObservationIgnored
    private var generateTokensTask: Task<Void, Never>?
    @ObservationIgnored
    private var task: Task<Void, Never>?

    init() {
        cancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, !pauseRefreshing else {
                    return
                }
                refreshTokens()
            }
    }

    func process(uri: String) {
        task?.cancel()
        task = Task {
            do {
                try await entryDataService.insertAndRefreshEntry(from: uri)
            } catch {
                handle(error)
            }
        }
    }
}

extension EntriesViewModel {
    func setUp() async {
//        do {
//            entries = if let mocked = mockedEntries() {
//                mocked
//            } else {
//                try await getEntries()
//            }
//        } catch {
//            handle(error)
//        }
    }

    func refreshTokens() {
        generateTokensTask?.cancel()
        generateTokensTask = Task { [weak self] in
            guard let self else { return }
            do {
                if qaService.showMockEntries {
                    await qaService.mockedEntries()
                } else {
                    try await entryDataService.updateEntries()
                }
            } catch {
                handle(error)
            }
        }
    }

    func copyTokenToClipboard(_ entry: EntryUiModel) {
        let code = entry.code.current
        assert(!code.isEmpty, "Code should not be empty")
        copyTextToClipboard(code)
    }

    func toggleCodeRefresh(_ shouldPause: Bool) {
        pauseRefreshing = shouldPause
        if !pauseRefreshing {
            refreshTokens()
        }
    }

    func delete(_ entry: EntryUiModel) {
        Task {
            do {
                try await entryDataService.delete(entry)
            } catch {
                handle(error)
            }
        }
    }
}

private extension EntriesViewModel {
    func handle(_ error: any Error) {
        // swiftlint:disable:next todo
        // TODO: Log and display error to the users
        alertService.showError(error)
    }
}
