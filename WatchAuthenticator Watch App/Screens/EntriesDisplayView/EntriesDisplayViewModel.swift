//
//
// EntriesDisplayViewModel.swift
// Proton Authenticator - Created on 24/07/2025.
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
// along with Proton Pass. If not, see https://www.gnu.org/licenses/.
//

import Combine
import FactoryKit
import Foundation
import Macro
import Models
import SimpleToast

@Observable
@MainActor
final class EntriesDisplayViewModel: ObservableObject {
    var entries: [UIModel] {
        guard !lastestQuery.isEmpty else {
            return entryDataService.dataState.data ?? []
        }

        let newResults = entryDataService.dataState.data?.filter {
            $0.orderedEntry.entry.name.lowercased().contains(lastestQuery) ||
                $0.orderedEntry.entry.issuer.lowercased().contains(lastestQuery)
        } ?? []

        return newResults
    }

    @ObservationIgnored var query = "" {
        didSet {
            searchTextStream.send(query)
        }
    }

    var dataState: DataState<[UIModel]> {
        entryDataService.dataState
    }

    var toast: SimpleToast?

    @ObservationIgnored
    var waitingForData: Bool {
        entryDataService.waitingForUpdate
    }

    @ObservationIgnored
    @LazyInjected(\WatchDIContainer.dataService)
    private(set) var entryDataService

    private var lastestQuery = ""

    @ObservationIgnored
    private let searchTextStream: CurrentValueSubject<String, Never> = .init("")

    @ObservationIgnored
    private var cancellables = Set<AnyCancellable>()

    @ObservationIgnored
    private var loadLocalTask: Task<Void, Never>?

    init() {
        searchTextStream
            .dropFirst()
            .removeDuplicates()
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newSearch in
                guard let self else { return }
                lastestQuery = newSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            }
            .store(in: &cancellables)
    }

    func loadEntries() {
        loadLocalTask?.cancel()
        loadLocalTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await entryDataService.loadEntries()
            } catch {
                print("error loading entries: \(error)")
            }
        }
    }

    func askForUpdate() async {
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        entryDataService.askForDataUpdate()
    }

    func copyToWatchClipboard(_ code: String?) {
        guard let code else {
            return
        }
        entryDataService.sendCode(code)
        toast = SimpleToast(title: #localized("Copied to phone clipboard")) // ignore:missing_bundle
    }
}
