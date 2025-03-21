//
// EntryDataService.swift
// Proton Authenticator - Created on 28/02/2025.
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

import Combine
import CoreData
import Foundation
import Models

@MainActor
public protocol EntryDataServiceProtocol: Sendable, Observable {
    var dataState: DataState<[EntryUiModel]> { get }

    func getEntry(from uri: String) async throws -> Entry
    func insertAndRefreshEntry(from uri: String) async throws
    func insertAndRefreshEntry(from params: EntryParameters) async throws
    func updateAndRefreshEntry(for entryId: String, with params: EntryParameters) async throws
    func insertAndRefresh(entry: Entry) async throws
    func updateEntries() async throws
    func delete(_ entry: EntryUiModel) async throws
    func reorderItem(from currentPosition: Int, to newPosition: Int) async throws

    // MARK: - Expose repo functionalities to not have to inject several data source in view models

    func getTotpParams(entry: Entry) throws -> TotpParams
    func exportEntries() throws -> String
    func importEntries(from provenance: TwofaImportDestination) async throws -> Int
}

@MainActor
@Observable
public final class EntryDataService: EntryDataServiceProtocol {
    // MARK: - Properties

    public private(set) var dataState: DataState<[EntryUiModel]> = .loading

    @ObservationIgnored
    private let repository: any EntryRepositoryProtocol
    @ObservationIgnored
    private let importService: any ImportingServicing
    @ObservationIgnored
    private var task: Task<Void, Never>?
    @ObservationIgnored
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    public init(repository: any EntryRepositoryProtocol,
                importService: any ImportingServicing) {
        self.repository = repository
        self.importService = importService
        setUp()
    }

    private func setUp() {
        loadEntries()

        NotificationCenter.default.publisher(for: NSPersistentCloudKitContainer.eventChangedNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                let key = NSPersistentCloudKitContainer.eventNotificationUserInfoKey
                guard let self,
                      let event = notification.userInfo?[key] as? NSPersistentCloudKitContainer.Event,
                      event.endDate != nil, event.type == .import else { return }
                loadEntries()
            }
            .store(in: &cancellables)
    }
}

public extension EntryDataService {
    func getEntry(from uri: String) async throws -> Entry {
        try await repository.entry(for: uri)
    }

    func insertAndRefresh(entry: Entry) async throws {
        try await save(entry)
    }

    func insertAndRefreshEntry(from uri: String) async throws {
        let entry = try await repository.entry(for: uri)
        try await save(entry)
    }

    func insertAndRefreshEntry(from params: EntryParameters) async throws {
        let entry = try createEntry(with: params)
        try await save(entry)
    }

    func updateAndRefreshEntry(for entryId: String, with params: EntryParameters) async throws {
        var entry = try createEntry(with: params)
        entry.id = entryId
        try await repository.update(entry)

        var data: [EntryUiModel] = dataState.data ?? []
        if let index = data.firstIndex(where: { $0.id == entryId }) {
            data[index] = data[index].copy(newEntry: entry)
        }
        dataState = .loaded(data)
    }

    func updateEntries() async throws {
        let uiModels = try await updateEntries(for: .now)
        dataState = .loaded(uiModels)
    }

    func delete(_ entry: EntryUiModel) async throws {
        guard var data = dataState.data else {
            return
        }
        try await repository.remove(entry.entry.id)
        data = data.filter { $0.entry.id != entry.entry.id }
        data = updateOrder(data: data)
        try await repository.updateOrder(data)
        dataState = .loaded(data)
    }

    func reorderItem(from currentPosition: Int, to newPosition: Int) async throws {
        guard let entry = dataState.data?[currentPosition] else {
            return
        }
        guard var data = dataState.data else {
            return
        }
        data.remove(at: currentPosition)
        data.insert(entry, at: newPosition)
        data = updateOrder(data: data)
        try await repository.updateOrder(data)
        dataState = .loaded(data)
    }
}

// MARK: - Rust exposure

public extension EntryDataService {
    func getTotpParams(entry: Entry) throws -> TotpParams {
        try repository.getTotpParams(entry: entry)
    }

    func exportEntries() throws -> String {
        guard let data = dataState.data else {
            throw AuthError.generic(.exportEmptyData)
        }
        let entries = data.map(\.entry)
        return try repository.export(entries: entries)
    }

    nonisolated func importEntries(from provenance: TwofaImportDestination) async throws -> Int {
        let results = try importService.importEntries(from: provenance)
        var data: [EntryUiModel] = await dataState.data ?? []
        let filteredResults = results.entries
            .filter { entry in !data.contains(where: { $0.entry.isDuplicate(of: entry) }) }
        let codes = try repository.generateCodes(entries: filteredResults)

        var index = data.count
        var uiEntries: [EntryUiModel] = []
        for code in codes {
            uiEntries.append(EntryUiModel(entry: code.entry, code: code, order: index, date: .now))
            index += 1
        }
        try await repository.save(uiEntries)

        data.append(contentsOf: uiEntries)
        await MainActor.run {
            dataState = .loaded(data)
        }
        return uiEntries.count
    }
}

private extension EntryDataService {
    func loadEntries() {
        task?.cancel()
        task = Task { [weak self] in
            guard let self else { return }
            do {
                if Task.isCancelled { return }
                let entriesStates = try await repository.getAllEntries()
                if Task.isCancelled { return }
                dataState = try await .loaded(generateUIEntries(from: entriesStates.decodedEntries))
            } catch {
                if let data = dataState.data, !data.isEmpty { return }
                dataState = .failed(error)
            }
        }
    }

    func save(_ entry: Entry) async throws {
        var data: [EntryUiModel] = dataState.data ?? []

        guard !data.contains(where: { $0.entry.isDuplicate(of: entry) }) else {
            throw AuthError.generic(.duplicatedEntry)
        }

        let codes = try repository.generateCodes(entries: [entry])
        guard let code = codes.first else {
            throw AuthError.generic(.missingGeneratedCodes(codeCount: codes.count,
                                                           entryCount: 1))
        }
        let order = data.count
        let entryUI = EntryUiModel(entry: code.entry, code: code, order: order, date: .now)
        try await repository.save(entryUI)

        data.append(entryUI)
        dataState = .loaded(data)
    }

    func createEntry(with params: EntryParameters) throws -> Entry {
        switch params {
        case let .steam(params):
            try repository.createSteamEntry(params: params)
        case let .totp(params):
            try repository.createTotpEntry(params: params)
        }
    }

    func generateUIEntries(from entries: [Entry]) async throws -> [EntryUiModel] {
        let codes = try repository.generateCodes(entries: entries)
        guard codes.count == entries.count else {
            throw AuthError.generic(.missingGeneratedCodes(codeCount: codes.count,
                                                           entryCount: entries.count))
        }

        var results = [EntryUiModel]()
        for (index, code) in codes.enumerated() {
            guard let entry = entries[safeIndex: index] else {
                throw AuthError.generic(.missingEntryForGeneratedCode)
            }
            results.append(.init(entry: entry, code: code, order: index, date: .now))
        }

        return results
    }

    nonisolated func updateEntries(for date: Date) async throws -> [EntryUiModel] {
        guard let uiEntries: [EntryUiModel] = await dataState.data else {
            return []
        }

        if uiEntries.contains(where: { $0.progress.countdown == 0 }) {
            let entries = uiEntries.map(\.entry)

            let codes = try repository.generateCodes(entries: entries)
            var results = [EntryUiModel]()
            for (index, code) in codes.enumerated() {
                results.append(.init(entry: code.entry, code: code, order: index, date: date))
            }
            return results
        } else {
            return uiEntries.map { $0.updateProgress() }
        }
    }

    func updateOrder(data: [EntryUiModel]?) -> [EntryUiModel] {
        guard var data else {
            return []
        }

        for (index, entry) in data.enumerated() where entry.order != index {
            data[index] = entry.updateOrder(index)
        }
        return data
    }
}

public extension [EntryState] {
    var decodedEntries: [Entry] {
        compactMap(\.entry)
    }
}
