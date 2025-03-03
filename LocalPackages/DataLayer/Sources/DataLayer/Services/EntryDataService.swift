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

import DomainProtocols
import Foundation
import Models

public enum DataState<T: Sendable & Equatable & Hashable & Identifiable>: Sendable, Equatable, Hashable {
    case loading
    case loaded([T])
    case failed(String)

    public var data: [T] {
        switch self {
        case let .loaded(data):
            data
        default:
            []
        }
    }
}

@MainActor
public protocol EntryDataServicing: Sendable, Observable {
    var dataState: DataState<EntryUiModel> { get }

    func generateEntry(from payload: String) async throws
    func refreshEntries(entries: [EntryUiModel])
}

@MainActor
@Observable
public final class EntryDataService: EntryDataServicing {
    // MARK: - Properties

    public private(set) var dataState: DataState<EntryUiModel> = .loading

    private let repository: any EntryRepositoryProtocol
    private var task: Task<Void, Never>?

    // MARK: - Init

    public init(repository: any EntryRepositoryProtocol) {
        self.repository = repository
        setUp()
    }

    private func setUp() {
        guard task == nil else { return }
        task = Task {}
    }

    public func generateEntry(from payload: String) async throws {
        let entry = try await repository.entry(for: payload)
        let codes = try repository.generateCodes(entries: [entry])
        guard let code = codes.first else {
            throw AuthenticatorError.missingGeneratedCodes(codeCount: codes.count,
                                                           entryCount: 1)
        }
        let entryUI = EntryUiModel(entry: entry, code: code, date: .now)
        var data: [EntryUiModel] = dataState.data
        data.append(entryUI)
        dataState = .loaded(data)
    }

    public func refreshEntries(entries: [EntryUiModel]) {
        dataState = .loaded(entries)
    }
}
