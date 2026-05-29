//
// MockedBackUpManager.swift
// Proton Authenticator - Created on 27/05/2026.
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
final class MockedBackUpManager: BackUpServicing {
    private(set) var resolveDestinationFolderCalled = 0
    private(set) var lastResolvedBookmark: Data?

    var resolveError: Error?
    var resolvedURL = URL(fileURLWithPath: "/tmp/mock-backup")

    func write(data: Data) throws {}

    func read(fileName: String) throws -> Data { Data() }

    func getAllDocumentsData() throws -> [BackUpFileInfo] { [] }

    func delete(fileName: String) throws {}

    func deleteAllBackupFiles() throws {}

    func setDestinationFolder(_ url: URL) {}

    func resolveDestinationFolder(from bookmarkData: Data) throws -> URL {
        resolveDestinationFolderCalled += 1
        lastResolvedBookmark = bookmarkData
        if let resolveError { throw resolveError }
        return resolvedURL
    }

    func clearDestinationFolder() {}
}
