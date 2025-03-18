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
}

@MainActor
@Observable
public final class EntryDataService: EntryDataServiceProtocol {
    // MARK: - Properties

    public private(set) var dataState: DataState<[EntryUiModel]> = .loading

    @ObservationIgnored
    private let repository: any EntryRepositoryProtocol
    @ObservationIgnored
    private var task: Task<Void, Never>?
    @ObservationIgnored
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    public init(repository: any EntryRepositoryProtocol) {
        self.repository = repository
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
        try await repository.remove(entry.entry.id)
        var data = dataState.data?.filter { $0.entry.id != entry.entry.id }
        data = updateOrder(data: data)
        try await repository.updateOrder(data ?? [])
        dataState = .loaded(data ?? [])
    }

    func reorderItem(from currentPosition: Int, to newPosition: Int) async throws {
        guard let entry = dataState.data?[currentPosition] else {
            return
        }
        var data = dataState.data
        data?.remove(at: currentPosition)
        data?.insert(entry, at: newPosition)
        data = updateOrder(data: data)
        try await repository.updateOrder(data ?? [])
        dataState = .loaded(data ?? [])
    }

    //            // Get the item being moved
    //            let movedItem = items[offset]
    //
    //            // Remove the item from the array
    //            items.remove(at: offset)
    //
    //            // Insert the item at the new position
    //            items.insert(movedItem, at: targetIndex)
    //
    //            // Update the order property for affected items only
    //            modelContext.perform {
    //                for (index, item) in items.enumerated() {
    //                    // Only update if the order has changed
    //                    if item.order != index {
    //                        item.order = index
    //                    }
    //                }
    //            }
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
                dataState = .failed(error)
            }
        }
    }

    func save(_ entry: Entry) async throws {
        var data: [EntryUiModel] = dataState.data ?? []

        let codes = try repository.generateCodes(entries: [entry])
        guard let code = codes.first else {
            throw AuthError.generic(.missingGeneratedCodes(codeCount: codes.count,
                                                           entryCount: 1))
        }
        let order = data.count
        let entryUI = EntryUiModel(entry: code.entry, code: code, order: order, date: .now)
        try await repository.save(OrderedEntry(entry: entry, order: order))

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
