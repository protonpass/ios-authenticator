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

import CommonUtilities
import Foundation

@MainActor
public protocol QAServicing: Sendable, Observable {
    var showMockEntries: Bool { get set }
    var numberOfMockEntries: Int { get set }
}

@MainActor
@Observable
public final class QAService: QAServicing {
    @ObservationIgnored
    private let store: UserDefaults

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
            }
        }
    }

    public init(store: UserDefaults) {
        self.store = store
        showMockEntries = store.bool(forKey: AppConstants.QA.mockEntriesDisplay)
        numberOfMockEntries = store.integer(forKey: AppConstants.QA.mockEntriesCount)
    }
}
