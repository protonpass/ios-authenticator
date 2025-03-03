//
// GenerateEntryUiModels.swift
// Proton Authenticator - Created on 25/02/2025.
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

import CommonUtilities
import DataLayer
import DomainProtocols
import Foundation
import Models

public protocol GenerateEntryUiModelsUseCase: Sendable {
    func execute( /* from entries: [Entry], */ on date: Date) async throws -> [EntryUiModel]
}

public extension GenerateEntryUiModelsUseCase {
    func callAsFunction( /* from entries: [Entry], */ on date: Date = .now) async throws -> [EntryUiModel] {
        try await execute( /* from: entries, */ on: date)
    }
}

// swiftlint:disable:next todo
// TODO: maybe move this in a service ?

public final class GenerateEntryUiModels: GenerateEntryUiModelsUseCase {
    private let repository: any EntryRepositoryProtocol
    private let service: any EntryDataServicing

    public init(repository: any EntryRepositoryProtocol,
                service: any EntryDataServicing) {
        self.repository = repository
        self.service = service
    }

    public func execute( /* from entries: [Entry], */ on date: Date = .now) async throws -> [EntryUiModel] {
        let entries = await service.dataState.data.map(\.entry)
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
            results.append(.init(entry: entry, code: code, date: date))
        }
        await service.refreshEntries(entries: results)
        return results
    }
}
