//
// EntryDataServiceLogoutTests.swift
// Proton Authenticator - Created on 28/09/2026.
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

import CommonUtilities
@testable import DataLayer
import Foundation
import Models
import Testing

@Suite(.tags(.service))
@MainActor
struct EntryDataServiceLogoutTests {
    let sut: EntryDataService
    let mockUserSession: MockUserSessionTooling
    let mockRepository: MockEntryRepository
    let mockBackUpManager: MockBackUpManager
    let mockSettings: MockSettingsService
    let mockKeychain: MockKeychainService

    init() {
        mockUserSession = MockUserSessionTooling()
        mockRepository = MockEntryRepository()
        mockBackUpManager = MockBackUpManager()
        mockSettings = MockSettingsService()
        mockKeychain = MockKeychainService()
        sut = Self.makeSut(repository: mockRepository,
                           backUpManager: mockBackUpManager,
                           settings: mockSettings,
                           keychain: mockKeychain,
                           userSession: mockUserSession)
    }

    // MARK: - Helpers

    private static func makeSut(repository: MockEntryRepository,
                                backUpManager: MockBackUpManager,
                                settings: MockSettingsService,
                                keychain: MockKeychainService,
                                userSession: MockUserSessionTooling) -> EntryDataService {
        EntryDataService(repository: repository,
                         importService: MockImportingService(),
                         totpGenerator: MockTotpGenerator(),
                         totpIssuerMapper: MockTotpIssuerMapper(),
                         logger: MockLogger(),
                         reachabilityManager: MockReachabilityManager(),
                         backUpManager: backUpManager,
                         settings: settings,
                         keychainService: keychain,
                         userSessionManager: userSession,
                         syncOperation: MockSyncOperationChecker())
    }

    private func makeEntryState(id: String, name: String, order: Int) -> EntryState {
        let entry = Entry(id: id, name: name,
                          uri: "otpauth://totp/\(name)?secret=ABCDEFGH&issuer=TestIssuer",
                          period: 30, issuer: "TestIssuer", secret: "ABCDEFGH", type: .totp, note: nil)
        let orderedEntry = OrderedEntry(entry: entry, keyId: "key-id", remoteId: "remote-\(id)",
                                        order: order, modifiedTime: Date.now.timeIntervalSince1970,
                                        revision: 1, contentFormatVersion: 1)
        let entity = EncryptedEntryEntity(id: id,
                                          encryptedData: Data(),
                                          remoteId: "remote-\(id)",
                                          keyId: "key-id",
                                          order: order,
                                          syncState: .unsynced,
                                          creationDate: Date.now.timeIntervalSince1970,
                                          modifiedTime: Date.now.timeIntervalSince1970)
        return .decrypted(entity.encryptedEntry, orderedEntry)
    }

    /// The logout handler hops to the main queue then spawns a `Task`, so results are observed asynchronously.
    private func waitUntil(timeout: Duration = .seconds(2),
                           sourceLocation: SourceLocation = #_sourceLocation,
                           _ condition: () -> Bool) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now + timeout
        while !condition() {
            guard clock.now < deadline else {
                Issue.record("Condition not met within \(timeout)", sourceLocation: sourceLocation)
                return
            }
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    /// Gives the logout pipeline a chance to run when asserting that something did NOT happen.
    private func drainPendingWork() async throws {
        try await Task.sleep(for: .milliseconds(200))
    }

    // MARK: - Tests

    @Test
    func `Does not unsync entries when no logout happens`() async throws {
        try await drainPendingWork()

        #expect(mockRepository.unsyncAllEntriesCalled == 0)
    }

    @Test
    func `Unsyncs all entries when the user is logged out`() async throws {
        mockUserSession.userLoggedOut.send()

        try await waitUntil { mockRepository.unsyncAllEntriesCalled == 1 }
        #expect(mockRepository.unsyncAllEntriesCalled == 1)
    }

    @Test
    func `Reloads data state from local storage after logout`() async throws {
        mockRepository.allLocalEntries = [
            makeEntryState(id: "entry-1", name: "First", order: 0),
            makeEntryState(id: "entry-2", name: "Second", order: 1)
        ]

        mockUserSession.userLoggedOut.send()

        try await waitUntil { sut.dataState.data?.count == 2 }
        #expect(sut.dataState.data?.map(\.orderedEntry.entry.id) == ["entry-1", "entry-2"])
    }

    @Test
    func `Writes a backup after logout when folder backup is enabled`() async throws {
        mockRepository.allLocalEntries = [makeEntryState(id: "entry-1", name: "First", order: 0)]
        mockSettings.folderBackup = true
        try mockKeychain.set("test-password", for: AppConstants.Settings.backupPassword, shouldSync: false)

        mockUserSession.userLoggedOut.send()

        try await waitUntil { mockBackUpManager.writeCalled == 1 }
        #expect(mockBackUpManager.lastWrittenData == mockRepository.exportResult.data(using: .utf8))
    }

    @Test
    func `Unsyncs on every logout event such as a manual logout followed by a forced logout`() async throws {
        mockUserSession.userLoggedOut.send()
        try await waitUntil { mockRepository.unsyncAllEntriesCalled == 1 }

        mockUserSession.userLoggedOut.send()
        try await waitUntil { mockRepository.unsyncAllEntriesCalled == 2 }

        #expect(mockRepository.unsyncAllEntriesCalled == 2)
    }

    @Test
    func `Swallows unsync failure on logout and leaves data state and backup untouched`() async throws {
        mockRepository.unsyncAllEntriesError = EntryServiceTestError.failTest
        mockRepository.allLocalEntries = [makeEntryState(id: "entry-1", name: "First", order: 0)]
        mockSettings.folderBackup = true
        try mockKeychain.set("test-password", for: AppConstants.Settings.backupPassword, shouldSync: false)

        mockUserSession.userLoggedOut.send()

        try await waitUntil { mockRepository.unsyncAllEntriesCalled == 1 }
        try await drainPendingWork()
        #expect(mockRepository.getAllLocalEntriesCalled == 0)
        #expect(mockBackUpManager.writeCalled == 0)
        if case .loading = sut.dataState { } else { Issue.record("expected dataState to stay .loading") }
    }

    @Test
    func `Logout subscription does not retain the service`() async throws {
        let repository = MockEntryRepository()
        var service: EntryDataService? = Self.makeSut(repository: repository,
                                                      backUpManager: MockBackUpManager(),
                                                      settings: MockSettingsService(),
                                                      keychain: MockKeychainService(),
                                                      userSession: mockUserSession)
        weak var weakService = service
        service = nil
        #expect(weakService == nil)

        mockUserSession.userLoggedOut.send()
        try await drainPendingWork()

        #expect(repository.unsyncAllEntriesCalled == 0)
    }
}
