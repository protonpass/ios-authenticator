//
// QAService.swift
// Proton Authenticator - Created on 21/02/2025.
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

// periphery:ignore:all

import CommonUtilities
import Foundation
import Models

@MainActor
public protocol QAServicing: Sendable, Observable {
    var showMockEntries: Bool { get set }
    var numberOfMockEntries: Int { get set }
    var dataState: DataState<[EntryUiModel]> { get }

    func mockedEntries() async
}

@MainActor
@Observable
public final class QAService: QAServicing {
    @ObservationIgnored
    private let store: UserDefaults
    @ObservationIgnored
    private let repository: any EntryRepositoryProtocol

    public private(set) var dataState: DataState<[EntryUiModel]> = .loading

    public var showMockEntries: Bool {
        didSet {
            if showMockEntries != oldValue {
                store.set(showMockEntries, forKey: AppConstants.QA.mockEntriesDisplay)
            }
        }
    }

    public var numberOfMockEntries: Int {
        didSet {
            if numberOfMockEntries != oldValue {
                store.set(numberOfMockEntries, forKey: AppConstants.QA.mockEntriesCount)
                mockedEntries()
            }
        }
    }

    public init(store: UserDefaults,
                repository: any EntryRepositoryProtocol) {
        self.store = store
        self.repository = repository
        showMockEntries = AppConstants.isQaBuild ? store.bool(forKey: AppConstants.QA.mockEntriesDisplay) : false
        numberOfMockEntries = store.integer(forKey: AppConstants.QA.mockEntriesCount)
    }

    public func mockedEntries() {
        let count = max(5, numberOfMockEntries)

        var entries = [Entry]()
        for index in 0..<count {
            entries.append(.init(id: UUID().uuidString,
                                 name: "Test #\(index)",
                                 uri: "otpauth://totp/SimpleLogin:john.doe\(index)%40example.com?secret=CKTQQJVWT5IXTGD\(index)&amp;issuer=SimpleLogin",
                                 period: 30,
                                 issuer: "Proton",
                                 secret: "aaaa",
                                 type: .totp,
                                 note: "Note #\(index)"))
        }

        let codes = try? repository.generateCodes(entries: entries)
        guard let codes else {
            return
        }
        var results = [EntryUiModel]()
        for (index, code) in codes.enumerated() {
            guard let entry = entries[safeIndex: index] else {
                return
            }
            results.append(.init(entry: entry,
                                 code: code,
                                 order: index,
                                 syncState: .unsynced,
                                 remoteId: nil,
                                 issuerInfo: nil))
        }
        dataState = .loaded(results)
    }
}
