//
// DataService.swift
// Proton Authenticator - Created on 25/07/2025.
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

import Combine
import Foundation
import Models
import OneTimePassword

@MainActor
protocol DataServiceProtocol: Sendable, Observable {
    var dataState: DataState<[UIModel]> { get }
    var waitingForUpdate: Bool { get }

    func loadEntries() async throws
    func askForDataUpdate()
    func sendCode(_ code: String)
}

struct UIModel: Hashable, Identifiable {
    let orderedEntry: OrderedEntry
    let token: Token

    var id: String {
        orderedEntry.id
    }
}

@MainActor
@Observable
final class DataService: DataServiceProtocol {
    // MARK: - Properties

    private(set) var dataState: DataState<[UIModel]> = .loading

    @ObservationIgnored
    private let repository: any EntryRepositoryProtocol

    @ObservationIgnored
    private let communicationService: any WatchCommunicationServiceProtocol

    @ObservationIgnored
    private var cancellables = Set<AnyCancellable>()

    var waitingForUpdate: Bool {
        communicationService.communicationState.value == .waitingForMessage
    }

    // MARK: - Init

    init(repository: any EntryRepositoryProtocol,
         communicationService: any WatchCommunicationServiceProtocol) {
        self.repository = repository
        self.communicationService = communicationService
        setUp()
    }

    private func setUp() {
        communicationService
            .communicationState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self else { return }
                parse(state)
            }
            .store(in: &cancellables)
    }

    func loadEntries() async throws {
        do {
            if Task.isCancelled { return }
//            let entriesStates = try await repository.getAllEntries()
//            if entriesStates.isEmpty {
            askForDataUpdate()
//            }
            if Task.isCancelled { return }
            let entries = try await generateUIEntries(from: [] /* entriesStates */ )
            updateData(entries)
        } catch {
            if let data = dataState.data, !data.isEmpty { return }
            dataState = .failed(error)
        }
    }

    func generateUIEntries(from entries: [OrderedEntry]) async throws -> [UIModel] {
        var results = [UIModel]()
        for entry in entries {
            guard let url = URL(string: entry.entry.uri), let token = try? Token(url: url) else {
                continue
            }
            results.append(.init(orderedEntry: entry, token: token))
        }

        return results
    }

    func updateData(_ entries: [UIModel]) {
        dataState = .loaded(entries)
    }

    func askForDataUpdate() {
//        guard !waitingForUpdate else {
//            return
//        }
        do {
            try communicationService.sendMessage(message: .syncData)
        } catch {
            dataState = .failed(error)
//            print("\(error.localizedDescription)")
        }
    }

    func sendCode(_ code: String) {
        do {
            try communicationService.sendMessage(message: .code(code))
        } catch {
            dataState = .failed(error)

//            print("\(error.localizedDescription)")
        }
    }

    func parse(_ status: CommunicationState) {
        switch status {
        case .waitingForMessage:
            return
        case let .responseReceived(result):
            switch result {
            case let .success(entries):
                manageReceivedData(entries)
            case let .failure(error):
                dataState = .failed(error)
//                print("Error: \(error.localizedDescription)")
            }
        case .idle:
            return
        }
    }

    func manageReceivedData(_ entries: [OrderedEntry]) {
        if let currentData = dataState.data, currentData.map(\.orderedEntry) == entries {
            return
        }

        Task { [weak self] in
            guard let self else { return }
            do {
                if let currentData = dataState.data {
                    let newIds = entries.ids
                    let existingIds = currentData.ids
                    let idsToDelete = existingIds.subtracting(newIds)
//                    if !idsToDelete.isEmpty {
//                        try await repository.removeAll(Array(idsToDelete))
//                    }
                }
//                try await repository.upsert(entries)
                let entries = try await generateUIEntries(from: entries)
                updateData(entries)
            } catch {
                dataState = .failed(error)

//                print("Failed manageReceivedData: \(error)")
            }
        }
    }
}

private extension [OrderedEntry] {
    var ids: Set<String> {
        Set(self.map(\.id))
    }
}

private extension [UIModel] {
    var ids: Set<String> {
        Set(self.map(\.id))
    }
}
