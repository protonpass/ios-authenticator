//
// MockedEntryDataService.swift
// Proton Authenticator - Created on 17/06/2025.
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
//

import DataLayer
import Models

final class MockedEntryDataService: EntryDataServiceProtocol {
    init() {}

    var dataState: DataState<[EntryUiModel]> = .loading

    func getEntry(from uri: String) async throws -> Entry {
        .init(id: "",
              name: "",
              uri: "",
              period: 0,
              issuer: "",
              secret: "",
              type: .totp,
              note: nil)
    }
    
    func insertAndRefreshEntry(from uri: String) async throws {}
    
    func insertAndRefreshEntry(from params: EntryParameters) async throws {}
    
    func updateAndRefreshEntry(for entryId: String, with params: EntryParameters) async throws {}
    
    func insertAndRefresh(entry: Entry) async throws {}
    
    func loadEntries() async throws {}
    
    func delete(_ entry: EntryUiModel) async throws {}
    
    func reorderItem(from currentPosition: Int, to newPosition: Int) async throws {}
    
    func fullRefresh() async throws {}
    
    func getTotpParams(entry: Entry) throws -> TotpParams {
        .init(name: "",
              secret: "",
              issuer: "",
              period: nil,
              digits: nil,
              algorithm: nil,
              note: nil)
    }

    func exportEntries() throws -> String {
        ""
    }

    func importEntries(from source: Models.TwofaImportSource) async throws -> Int {
        0
    }
    
    func stopTotpGenerator() {}
    
    func startTotpGenerator() {}
    
    func unsyncAllEntries() async throws {}
    
    func deleteAll() async throws {}

}
