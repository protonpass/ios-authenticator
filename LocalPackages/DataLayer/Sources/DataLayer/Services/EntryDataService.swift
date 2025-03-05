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

extension NSNotification.Name {
    static let fetchedData = Self(rawValue: "fetchedData")
}

@MainActor
public protocol EntryDataServiceProtocol: Sendable, Observable {
    var dataState: DataState<[EntryUiModel]> { get }

    func insertAndRefreshEntry(from payload: String) async throws
    func insertAndRefreshEntry(from params: EntryParamsParameter) async throws
//    func refreshEntries(entries: [EntryUiModel])
    func updateEntries() async throws
    func delete(_ entry: EntryUiModel) async throws
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
                guard let self,
                      let event = notification
                      .userInfo?[
                          NSPersistentCloudKitContainer
                              .eventNotificationUserInfoKey
                      ] as? NSPersistentCloudKitContainer.Event,
                      event.endDate != nil, event.type == .import else { return }
                loadEntries()
            }
            .store(in: &cancellables)
    }
}

public extension EntryDataService {
    func insertAndRefreshEntry(from uri: String) async throws {
        let entry = try await repository.entry(for: uri)
        try await save(entry)
    }

    func insertAndRefreshEntry(from params: EntryParamsParameter) async throws {
        let entry = if let totpParams = params as? TotpParams {
            try repository.createTotpEntry(params: totpParams)
        } else if let steamParams = params as? SteamParams {
            try repository.createSteamEntry(params: steamParams)
        } else {
            throw AuthError.entry(.wrongTypeOfEntryParams)
        }
        try await save(entry)
    }

//    func updateEntry(for entryId: String, with params: EntryParamsParameter) async throws {
//        update
//
//        try await repository.remove(entryId)
//        try await repository.save(entry)
//        let codes = try repository.generateCodes(entries: [entry])
//        guard let code = codes.first else {
//            throw AuthenticatorError.missingGeneratedCodes(codeCount: codes.count,
//                                                           entryCount: 1)
//        }
//        let entryUI = EntryUiModel(entry: entry, code: code, date: .now)
//        var data: [EntryUiModel] = dataState.data ?? []
//        data.append(entryUI)
//        dataState = .loaded(data)
//    }

    func updateEntries() async throws {
        let uiModels = try await updateEntries(for: .now)
        dataState = .loaded(uiModels)
    }

    func delete(_ entry: EntryUiModel) async throws {
        try await repository.remove(entry.entry)
        let data = dataState.data?.filter { $0.entry.id != entry.entry.id }
        dataState = .loaded(data ?? [])
    }
}

private extension EntryDataService {
    func loadEntries() {
        guard task == nil else { return }
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let entries = try await repository.getAllEntries()
                dataState = try await .loaded(generateUIEntries(from: entries))
            } catch {
                dataState = .failed(error)
            }
        }
    }

    func save(_ entry: Entry) async throws {
        try await repository.save(entry)
        let codes = try repository.generateCodes(entries: [entry])
        guard let code = codes.first else {
            throw AuthError.entry(.missingGeneratedCodes(codeCount: codes.count,
                                                         entryCount: 1))
        }
        let entryUI = EntryUiModel(entry: entry, code: code, date: .now)
        var data: [EntryUiModel] = dataState.data ?? []
        data.append(entryUI)
        dataState = .loaded(data)
    }

    func generateUIEntries(from entries: [Entry]) async throws -> [EntryUiModel] {
        let codes = try repository.generateCodes(entries: entries)
        guard codes.count == entries.count else {
            throw AuthError.entry(.missingGeneratedCodes(codeCount: codes.count,
                                                         entryCount: entries.count))
        }

        var results = [EntryUiModel]()
        for (index, code) in codes.enumerated() {
            guard let entry = entries[safeIndex: index] else {
                throw AuthError.entry(.missingEntryForGeneratedCode)
            }
            results.append(.init(entry: entry, code: code, date: .now))
        }

        return results
    }

    func refreshEntries(entries: [EntryUiModel]) {
        dataState = .loaded(entries)
    }

    nonisolated func updateEntries(for date: Date) async throws -> [EntryUiModel] {
        guard let entries = await dataState.data?.map(\.entry) else {
            return []
        }
        let codes = try repository.generateCodes(entries: entries)
        guard codes.count == entries.count else {
            throw AuthError.entry(.missingGeneratedCodes(codeCount: codes.count,
                                                         entryCount: entries.count))
        }
        var results = [EntryUiModel]()
        for (index, code) in codes.enumerated() {
            guard let entry = entries[safeIndex: index] else {
                throw AuthError.entry(.missingEntryForGeneratedCode)
            }
            results.append(.init(entry: entry, code: code, date: date))
        }
        return results
    }
}
