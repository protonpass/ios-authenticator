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

import AuthenticatorRustCore
import Combine
import CoreData
import Foundation
import Models

@MainActor
public protocol EntryDataServiceProtocol: Sendable, Observable {
    var dataState: DataState<[EntryUiModel]> { get }

    func getEntry(from uri: String) async throws -> Entry
    // periphery:ignore
    func insertAndRefreshEntry(from uri: String) async throws
    func insertAndRefreshEntry(from params: EntryParameters) async throws
    func updateAndRefreshEntry(for entryId: String, with params: EntryParameters) async throws
    func insertAndRefresh(entry: Entry) async throws
    func loadEntries()
    func delete(_ entry: EntryUiModel) async throws
    func reorderItem(from currentPosition: Int, to newPosition: Int) async throws

    // MARK: - Expose repo functionalities to not have to inject several data source in view models

    func getTotpParams(entry: Entry) throws -> TotpParams
    func exportEntries() throws -> String
    func importEntries(from source: TwofaImportSource) async throws -> Int
    func stopTotpGenerator()
    func startTotpGenerator()
}

public final class CurrentTimeProviderImpl: MobileCurrentTimeProvider {
    public init() {}

    public func now() -> UInt64 {
        UInt64(Date.now.timeIntervalSince1970)
    }
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
    @ObservationIgnored
    private var totpGenerator: any TotpGeneratorProtocol
    @ObservationIgnored
    private var entryUpdateTask: Task<Void, Never>?
    @ObservationIgnored
    private let totpIssuerMapper: any TOTPIssuerMapperServicing

    // MARK: - Init

    public init(repository: any EntryRepositoryProtocol,
                importService: any ImportingServicing,
                totpGenerator: any TotpGeneratorProtocol,
                totpIssuerMapper: any TOTPIssuerMapperServicing) {
        self.repository = repository
        self.importService = importService
        self.totpGenerator = totpGenerator
        self.totpIssuerMapper = totpIssuerMapper
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

        totpGenerator.currentCode
            .receive(on: DispatchQueue.main)
            .compactMap(\.self)
            .sink { [weak self] codes in
                guard let self else { return }
                dataState = .loaded(codes)
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

    // periphery:ignore
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
        updateData(data)
    }

    func delete(_ entry: EntryUiModel) async throws {
        guard var data = dataState.data else {
            return
        }
        try await repository.remove(entry.entry.id)
        data = data.filter { $0.entry.id != entry.entry.id }
        data = updateOrder(data: data)
        try await repository.updateOrder(data)
        updateData(data)
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
        updateData(data)
    }

    func loadEntries() {
        task?.cancel()
        task = Task { [weak self] in
            guard let self else { return }
            do {
                if Task.isCancelled { return }
                let entriesStates = try await repository.getAllEntries()
                if Task.isCancelled { return }
                let entries = try await generateUIEntries(from: entriesStates.decodedEntries)
                updateData(entries)
            } catch {
                if let data = dataState.data, !data.isEmpty { return }
                dataState = .failed(error)
            }
        }
    }

    func updateData(_ entries: [EntryUiModel]) {
        dataState = .loaded(entries)
        totpUpdate(entries.map(\.entry))
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

    nonisolated func importEntries(from source: TwofaImportSource) async throws -> Int {
        let results = try importService.importEntries(from: source)
        var data: [EntryUiModel] = await dataState.data ?? []
        let filteredResults = results.entries
            .filter { entry in !data.contains(where: { $0.entry.isDuplicate(of: entry) }) }
        let codes = try repository.generateCodes(entries: filteredResults)

        var index = data.count
        var uiEntries: [EntryUiModel] = []
        for code in codes {
            let issuerInfo = totpIssuerMapper.lookup(issuer: code.entry.issuer)
            uiEntries.append(EntryUiModel(entry: code.entry, code: code, order: index, issuerInfo: issuerInfo))
            index += 1
        }
        try await repository.save(uiEntries)

        data.append(contentsOf: uiEntries)
        await MainActor.run {
            updateData(data)
        }
        return uiEntries.count
    }

    func stopTotpGenerator() {
        entryUpdateTask?.cancel()
        entryUpdateTask = nil
        Task {
            await totpGenerator.stopUpdating()
        }
    }

    func startTotpGenerator() {
        entryUpdateTask?.cancel()
        entryUpdateTask = Task { [weak self] in
            guard let self, let data = dataState.data?.map(\.entry) else { return }
            do {
                try await totpGenerator.totpUpdate(data)
            } catch {
                // swiftlint:disable:next todo
                // TODO: log error
                print(error)
            }
        }
    }
}

private extension EntryDataService {
    func totpUpdate(_ entries: [Entry]) {
        entryUpdateTask?.cancel()
        entryUpdateTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await totpGenerator.totpUpdate(entries)
            } catch {
                // swiftlint:disable:next todo
                // TODO: log error
                print(error)
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
        let issuerInfo = totpIssuerMapper.lookup(issuer: code.entry.issuer)

        let entryUI = EntryUiModel(entry: code.entry, code: code, order: order, issuerInfo: issuerInfo)
        try await repository.save(entryUI)

        data.append(entryUI)
        updateData(data)
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
            let issuerInfo = totpIssuerMapper.lookup(issuer: code.entry.issuer)
            results.append(.init(entry: entry, code: code, order: index, issuerInfo: issuerInfo))
        }

        return results
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
