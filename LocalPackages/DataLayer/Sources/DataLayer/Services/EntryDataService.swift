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

import Foundation
import Models

@MainActor
public protocol EntryDataServiceProtocol: Sendable, Observable {
    var dataState: DataState<[EntryUiModel]> { get }

    func generateEntry(from payload: String) async throws
    func refreshEntries(entries: [EntryUiModel])
}

@MainActor
@Observable
public final class EntryDataService: EntryDataServiceProtocol {
    // MARK: - Properties

    public private(set) var dataState: DataState<[EntryUiModel]> = .loading

    private let repository: any EntryRepositoryProtocol
    private var task: Task<Void, Never>?

    // MARK: - Init

    public init(repository: any EntryRepositoryProtocol) {
        self.repository = repository
        setUp()
    }

    private func setUp() {
        guard task == nil else { return }
        task = Task {
            do {
                let entries = try await repository.getAllEntries()
                dataState = try await .loaded(generateUIEntries(from: entries))
            } catch {
                dataState = .failed(error)
            }
        }
    }

    public func generateEntry(from payload: String) async throws {
        let entry = try await repository.entry(for: payload)
        try await repository.save(entry)
        let codes = try repository.generateCodes(entries: [entry])
        guard let code = codes.first else {
            throw AuthenticatorError.missingGeneratedCodes(codeCount: codes.count,
                                                           entryCount: 1)
        }
        let entryUI = EntryUiModel(entry: entry, code: code, date: .now)
        var data: [EntryUiModel] = dataState.data ?? []
        data.append(entryUI)
        dataState = .loaded(data)
    }

    public func refreshEntries(entries: [EntryUiModel]) {
        dataState = .loaded(entries)
    }

    public func generateUIEntries(from entries: [Entry]) async throws -> [EntryUiModel] {
        let codes = try repository.generateCodes(entries: entries)
        guard codes.count == entries.count else {
            throw AuthenticatorError.missingGeneratedCodes(codeCount: codes.count,
                                                           entryCount: entries.count)
        }

        var results = [EntryUiModel]()
        for (index, code) in codes.enumerated() {
            guard let entry = entries[safeIndex: index] else {
                throw AuthenticatorError.missingEntryForGeneratedCode
            }
            results.append(.init(entry: entry, code: code, date: .now))
        }

        return results
    }
}
