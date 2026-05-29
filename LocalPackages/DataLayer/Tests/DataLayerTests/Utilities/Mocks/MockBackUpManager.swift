//
// MockBackUpManager.swift
// Proton Authenticator - Created on 19/02/2026.
// Copyright (c) 2026 Proton Technologies AG
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

import DataLayer
import Foundation

@MainActor
final class MockBackUpManager: BackUpServicing {
    private(set) var writeCalled = 0
    private(set) var lastWrittenData: Data?
    private(set) var saveDestinationFolderCalled = 0
    private(set) var clearDestinationFolderCalled = 0

    var destinationFolderURL: URL?
    var writeError: Error?
    var saveError: Error?

    func write(data: Data) throws {
        writeCalled += 1
        if let writeError { throw writeError }
        lastWrittenData = data
    }

    func read(fileName: String) throws -> Data { Data() }

    func getAllDocumentsData() throws -> [BackUpFileInfo] { [] }

    func delete(fileName: String) throws {}

    func deleteAllBackupFiles() throws {}

    func saveDestinationFolder(_ url: URL) throws {
        saveDestinationFolderCalled += 1
        if let saveError { throw saveError }
        destinationFolderURL = url
    }

    func clearDestinationFolder() {
        clearDestinationFolderCalled += 1
        destinationFolderURL = nil
    }
}
