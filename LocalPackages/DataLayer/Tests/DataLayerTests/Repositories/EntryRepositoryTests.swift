//  
// EntryRepositoryTests.swift
// Proton Authenticator - Created on 06/03/2025.
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
import SimplyPersist
import Testing
import Models
import SwiftData
@_spi(QA)
@testable import DataLayer

enum MockKeychainError: Error {
    case itemNotFound
    case typeMismatch
}

@Suite(.serialized, .tags(.repository))
struct EntryRepositoryTests {
    let sut: EntryRepositoryProtocol
    let encryptionService: any EncryptionServicing
    let localDataManager: MockLocalDataManager
    let apiClient: MockAPIClient
    let userSession: MockUserSessionTooling
    let store: UserDefaults

    init() throws {
        let persistenceService = try PersistenceService(with: ModelConfiguration(for: EncryptedEntryEntity.self,
                                                                                 isStoredInMemoryOnly: true))

        localDataManager = MockLocalDataManager(persistentStorage: persistenceService)
        encryptionService = EncryptionService(keysProvider: MockKeyProvider(),
                                              logger: MockLogger())
        apiClient = MockAPIClient()
        userSession = MockUserSessionTooling()
        store = UserDefaults(suiteName: "EntryRepositoryTests-\(UUID().uuidString)")!
        sut = EntryRepository(localDataManager: localDataManager,
                              encryptionService: encryptionService,
                              apiClient: apiClient,
                              userSessionManager: userSession,
                              store: store,
                              logger: MockLogger()
        )
    }
    
    @Test("Test generating entry for uri")
    func createEntryForUri() async throws {
        let uri = "otpauth://totp/SimpleLogin:john.doe%40example.com?secret=CKTQQJVWT5IXTGD&amp;issuer=SimpleLogin"
        // Act
        let entry = try await sut.entry(for: uri)

        // Assert
        #expect(entry.type == .totp)
        #expect(entry.name == "john.doe@example.com")
        #expect(entry.period == 30)
    }
    
    @Test("Test failing generating entry for bad uri")
    func failCreateEntryForUri() async throws {
        
        await #expect(throws: AuthenticatorError.self) {
            try await sut.entry(for: "this is a bad uri")
        }
    }
    
    @Test("Test exporting entries to json")
    func exportEntriesToJson() throws {
        
        let entries = [ Entry(id: "id",
                        name: "Test",
                        uri: "otpauth://totp/SimpleLogin:john.doe%40example.com?secret=CKTQQJVWT5IXTGD&amp;issuer=SimpleLogin",
                        period: 30,
                              issuer: "SimpleLogin",
                              secret: "CKTQQJVWT5IXTGD",
                        type: .totp,
                        note: "Note") ]
        
        let result = """
{"version":1,"entries":[{"id":"id","content":{"uri":"otpauth://totp/john.doe%40example.com?secret=CKTQQJVWT5IXTGD&issuer=SimpleLogin&algorithm=SHA1&digits=6&period=30","entry_type":"Totp","name":"john.doe@example.com"},"note":"Note"}]}
"""

        // Act
        let export = try sut.export(entries: entries)

        // Assert
        #expect(export == result)
    }
    
    @Test("Test serialized and deserializing entries")
    func serializingAndDeserializingEntries() throws {
        let entry = Entry(id: "id",
                        name: "Test",
                        uri: "otpauth://totp/Test?secret=CKTQQJVWT5IXTGD&issuer=SimpleLogin&algorithm=SHA1&digits=6&period=40",
                        period: 40,
                          issuer: "SimpleLogin",
                          secret: "CKTQQJVWT5IXTGD",
                        type: .totp,
                        note: "Note")
        let result = [entry]
        let serializedData = try sut.serialize(entries: result)
        // Act
        let export = try sut.deserialize(serializedData: serializedData)

        // Assert
        #expect(export.first?.name == result.first?.name)
        #expect(export.first?.period == result.first?.period)
    }
    
    @Test("Test generating code for entry")
    func generatingCodeForgEntries() throws {
        let entry = Entry(id: "id",
                        name: "Test",
                        uri: "otpauth://totp/SimpleLogin:john.doe%40example.com?secret=CKTQQJVWT5IXTGD&amp;issuer=SimpleLogin",
                        period: 40,
                          issuer: "SimpleLogin",
                          secret: "CKTQQJVWT5IXTGD",
                        type: .totp,
                        note: "Note")
        let result = [entry]
        let codes = try sut.generateCodes(entries: result, time: 1)
    

        // Assert
        #expect(codes.first?.current == "396323")
        #expect(codes.first?.next == "517416")
    }
    
    @Test("Test creating steam entry from params")
    func generatingSteamEntryFromParams() throws {
        let params = SteamParams(name: "Steam", secret: "aaaa", note: nil)
        let entry = try sut.createSteamEntry(params: params)
    
        // Assert
        #expect(entry.name == "Steam")
        #expect(entry.type == .steam)
    }
    
    @Test("Test creating totp entry from params")
    func generatingTotpEntryFromParams() throws {
        let params = TotpParams(name: "Totp", secret: "aaaa", issuer: "Proton", period: 40, digits: 7, algorithm: .sha1, note: nil)
        let entry = try sut.createTotpEntry(params: params)
    
        // Assert
        #expect(entry.name == "Totp")
        #expect(entry.type == .totp)
        #expect(entry.period == 40)
        #expect(entry.uri == "otpauth://totp/Totp?secret=aaaa&issuer=Proton&algorithm=SHA1&digits=7&period=40")
    }
    
    @Test("Test getting Totp params from entry")
    func gettingTotpParamsFromEntry() throws {
        let entry = Entry(id: "id",
                        name: "Test",
                        uri: "otpauth://totp/Test?secret=CKTQQJVWT5IXTGD&issuer=SimpleLogin&algorithm=SHA1&digits=6&period=40",
                        period: 40,
                          issuer: "SimpleLogin",
                          secret: "CKTQQJVWT5IXTGD",
                        type: .totp,
                        note: "Note")
        let params = try sut.getTotpParams(entry: entry)
    
        // Assert
        #expect(params.name == "Test")
        #expect(params.secret == "CKTQQJVWT5IXTGD")
        #expect(params.period == 40)
        #expect(params.digits == 6)
        #expect(params.algorithm == .sha1)
    }
    
    // MARK: - CRUD

    @Test("Test saving an entry in db")
    func savingAnEntry() async throws {
        let localKeyId = encryptionService.localEncryptionKeyId
        let entry = OrderedEntry(entry: Entry(id: "id",
                                              name: "Test",
                                              uri: "otpauth://totp/Test?secret=CKTQQJVWT5IXTGD&issuer=SimpleLogin&algorithm=SHA1&digits=6&period=40",
                                              period: 40,
                                                issuer: "SimpleLogin",
                                                secret: "CKTQQJVWT5IXTGD",
                                              type: .totp,
                                              note: "Note"), order: 0, keyId: localKeyId)
       
        try await sut.localUpsert(entry)
        
        var entries = try await sut.getAllLocalEntries().decodedEntries

        // Assert
        #expect(entries.count == 1)
        #expect(entries.first?.entry.period == entry.entry.period)
        #expect(entries.first?.entry.uri == entry.entry.uri)
        
        let entry2 = OrderedEntry(entry: Entry(id: "id2",
                                               name: "Test2",
                                               uri: "otpauth://totp/SimpleLogin:john.doe%40example.com?secret=CKTQQJVWT5IXTGD&amp;issuer=SimpleLogin",
                                               period: 30,
                                               issuer: "SimpleLogin",
                                               secret: "CKTQQJVWT5IXTGD",
                                               type: .totp,
                                               note: "Note"),
                                  order: 1,
                                  keyId: localKeyId)
       
        try await sut.localUpsert(entry2)
        entries = try await sut.getAllLocalEntries().decodedEntries

        // Assert
        #expect(entries.count == 2)
    }
    
    @Test("Test saving mutiple entry in db")
    func savingArrayOfEntry() async throws {
        let localKeyId = encryptionService.localEncryptionKeyId

        let entries: [OrderedEntry] = [
            .init(entry: Entry(id: "id",
                               name: "Test",
                               uri: "otpauth://totp/SimpleLogin:john.doe%40example.com?secret=CKTQQJVWT5IXTGD&amp;issuer=SimpleLogin",
                               period: 40,
                               issuer: "SimpleLogin",
                               secret: "CKTQQJVWT5IXTGD",
                               type: .totp,
                               note: "Note"),
                  order: 0,
                  keyId: localKeyId
            ),
            .init(entry: Entry(id: "id2",
                               name: "Test2",
                               uri: "otpauth://totp/SimpleLogin:john.doe%40example.com?secret=CKTQQJVWT5IXTGD&amp;issuer=SimpleLogin",
                               period: 30,
                               issuer: "SimpleLogin",
                               secret: "CKTQQJVWT5IXTGD",
                               type: .totp,
                               note: "Note"),
                  order:1,
                  keyId: localKeyId),
            .init(entry: Entry(id: "id3",
                               name: "Test3",
                               uri: "otpauth://totp/SimpleLogin:john.doe%40example.com?secret=CKTQQJVWT5IXTGD&amp;issuer=SimpleLogin",
                               period: 30,
                               issuer: "SimpleLogin",
                               secret: "CKTQQJVWT5IXTGD",
                               type: .totp,
                               note: "Note"),
                  order: 2,
                  keyId: localKeyId)
        ]
        
        try await sut.localUpsert(entries)
        
        let fetchedEntries = try await sut.getAllLocalEntries()

        // Assert
        #expect(fetchedEntries.count == 3)
    }
    
    @Test("Test removing all entries in db")
    func removingAllEntries() async throws {
        let localKeyId = encryptionService.localEncryptionKeyId

        let entries: [OrderedEntry] = [
            .init(entry:  Entry(id: "id",
                                name: "Test",
                                uri: "otpauth://totp/SimpleLogin:john.doe%40example.com?secret=CKTQQJVWT5IXTGD&amp;issuer=SimpleLogin",
                                period: 40,
                                issuer: "SimpleLogin",
                                secret: "CKTQQJVWT5IXTGD",
                                type: .totp,
                                note: "Note"),
                  order: 0,
                  keyId: localKeyId),
            .init(entry:  Entry(id: "id2",
                                name: "Test2",
                                uri: "otpauth://totp/SimpleLogin:john.doe%40example.com?secret=CKTQQJVWT5IXTGD&amp;issuer=SimpleLogin",
                                period: 30,
                                issuer: "SimpleLogin",
                                secret: "CKTQQJVWT5IXTGD",
                                type: .totp,
                                note: "Note"),
                  order:1,
                  keyId: localKeyId),
            .init(entry:  Entry(id: "id3",
                                name: "Test3",
                                uri: "otpauth://totp/SimpleLogin:john.doe%40example.com?secret=CKTQQJVWT5IXTGD&amp;issuer=SimpleLogin",
                                period: 30,
                                issuer: "SimpleLogin",
                                secret: "CKTQQJVWT5IXTGD",
                                type: .totp,
                                note: "Note"),
                  order: 2,
                  keyId: localKeyId),
        ]
       
        try await sut.localUpsert(entries)
        try await sut.localRemoveAll()
        
        let fetchedEntries = try await sut.getAllLocalEntries()

        // Assert
        #expect(fetchedEntries.count == 0)
    }
    
    @Test("Test removing one entry from db")
    func removingOneEntry() async throws {
        let localKeyId = encryptionService.localEncryptionKeyId

        let entries:[OrderedEntry] = [
            .init(entry: Entry(id: "id",
                                name: "Test",
                                uri: "otpauth://totp/SimpleLogin:john.doe%40example.com?secret=CKTQQJVWT5IXTGD&amp;issuer=SimpleLogin",
                                period: 40,
                                issuer: "SimpleLogin",
                                secret: "CKTQQJVWT5IXTGD",
                                type: .totp,
                                note: "Note"),
                  order: 0,
                  keyId: localKeyId),
            .init(entry: Entry(id: "id2",
                                name: "Test2",
                                uri: "otpauth://totp/SimpleLogin:john.doe%40example.com?secret=CKTQQJVWT5IXTGD&amp;issuer=SimpleLogin",
                                period: 30,
                                issuer: "SimpleLogin",
                                secret: "CKTQQJVWT5IXTGD",
                                type: .totp,
                                note: "Note"),
                  order: 1,
                  keyId: localKeyId),
            .init(entry: Entry(id: "id3",
                                 name: "Test3",
                                 uri: "otpauth://totp/SimpleLogin:john.doe%40example.com?secret=CKTQQJVWT5IXTGD&amp;issuer=SimpleLogin",
                                 period: 30,
                                 issuer: "SimpleLogin",
                                 secret: "CKTQQJVWT5IXTGD",
                                 type: .totp,
                                 note: "Note"),
                  order: 2,
                  keyId: localKeyId),
        ]
        
        try await sut.localUpsert(entries)
        try await sut.localRemoves([entries.first!.entry.id])
        
        var fetchedEntries = try await sut.getAllLocalEntries()

        // Assert
        #expect(fetchedEntries.count == 2)

        try await sut.localRemoves(["id2"])

         fetchedEntries = try await sut.getAllLocalEntries()

        // Assert
        #expect(fetchedEntries.count == 1)
    }

    @Test("Test updating one entry from db")
    func updateOneEntry() async throws {
        let localKeyId = encryptionService.localEncryptionKeyId

        let entries:[OrderedEntry] = [
            .init(entry: Entry(id: "id",
                               name: "Test",
                               uri: "otpauth://totp/SimpleLogin:john.doe%40example.com?secret=CKTQQJVWT5IXTGD&amp;issuer=SimpleLogin",
                               period: 40,
                               issuer: "SimpleLogin",
                               secret: "CKTQQJVWT5IXTGD",
                               type: .totp,
                               note: "Note"),
                  order: 0,
                  keyId: localKeyId),
            .init(entry:  Entry(id: "id2",
                                name: "Test2",
                                uri: "otpauth://totp/SimpleLogin:john.doe%40example.com?secret=CKTQQJVWT5IXTGD&amp;issuer=SimpleLogin",
                                period: 30,
                                issuer: "SimpleLogin",
                                secret: "CKTQQJVWT5IXTGD",
                                type: .totp,
                                note: "Note"),
                  order: 1,
                  keyId: localKeyId),
            .init(entry: Entry(id: "id3",
                               name: "Test3",
                               uri: "otpauth://totp/SimpleLogin:john.doe%40example.com?secret=CKTQQJVWT5IXTGD&amp;issuer=SimpleLogin",
                               period: 30,
                               issuer: "SimpleLogin",
                               secret: "CKTQQJVWT5IXTGD",
                               type: .totp,
                               note: "Note"),
                  order: 2,
                  keyId: localKeyId)
        ]
        
        let newEntry1 = OrderedEntry(entry: Entry(id: "id",
                                                  name: "Test",
                                                  uri: "otpauth://totp/SimpleLogin:john.doe%40example.com?secret=CKTQQJVWT5IXTGD&amp;issuer=SimpleLogin",
                                                  period: 40,
                                                  issuer: "SimpleLogin",
                                                  secret: "CKTQQJVWT5IXTGD",
                                                  type: .totp,
                                                  note: "new note"),
                                     order: 3,
                                     keyId: localKeyId)
        
        try await sut.localUpsert(entries)

       _ = try await sut.localUpdate(newEntry1)
        
        let fetchedEntries = try await sut.getAllLocalEntries().decodedEntries

        // Assert
        #expect(fetchedEntries.count == 3)

        #expect(fetchedEntries.map(\.entry.note).contains("new note") == true)
    }
    
    @Test("Test updating the order of an entries")
    func reorderEntry() async throws {
        let localKeyId = encryptionService.localEncryptionKeyId

        let entries:[OrderedEntry] = [
            .init(entry: Entry(id: "id0",
                               name: "Test",
                               uri: "otpauth://totp/SimpleLogin:john.doe%40example.com?secret=CKTQQJVWT5IXTGD&amp;issuer=SimpleLogin",
                               period: 40,
                               issuer: "SimpleLogin",
                               secret: "CKTQQJVWT5IXTGD",
                               type: .totp,
                               note: "Note"),
                  order: 0,
                  keyId: localKeyId),
            .init(entry: Entry(id: "id1",
                               name: "Test2",
                               uri: "otpauth://totp/SimpleLogin:john.doe%40example.com?secret=CKTQQJVWT5IXTGD&amp;issuer=SimpleLogin",
                               period: 30,
                               issuer: "SimpleLogin",
                               secret: "CKTQQJVWT5IXTGD",
                               type: .totp,
                               note: "Note"),
                  order: 1,
                  keyId: localKeyId),
            .init(entry: Entry(id: "id2",
                               name: "Test3",
                               uri: "otpauth://totp/SimpleLogin:john.doe%40example.com?secret=CKTQQJVWT5IXTGD&amp;issuer=SimpleLogin",
                               period: 30,
                               issuer: "SimpleLogin",
                               secret: "CKTQQJVWT5IXTGD",
                               type: .totp,
                               note: "Note"),
                  order: 2,
                  keyId: localKeyId),
            .init(entry: Entry(id: "id3",
                                      name: "Test",
                                      uri: "otpauth://totp/SimpleLogin:john.doe%40example.com?secret=CKTQQJVWT5IXTGD&amp;issuer=SimpleLogin",
                                      period: 40,
                                      issuer: "SimpleLogin",
                                      secret: "CKTQQJVWT5IXTGD",
                                      type: .totp,
                                      note: "new note"),
                         order: 3,
                         keyId: localKeyId)
        ]
        
        let reorderEntries:[OrderedEntry] = [
            .init(entry: Entry(id: "id3",
                               name: "Test",
                               uri: "otpauth://totp/SimpleLogin:john.doe%40example.com?secret=CKTQQJVWT5IXTGD&amp;issuer=SimpleLogin",
                               period: 40,
                               issuer: "SimpleLogin",
                               secret: "CKTQQJVWT5IXTGD",
                               type: .totp,
                               note: "Note"),
                  order: 0,
                  keyId: localKeyId),
            .init(entry: Entry(id: "id1",
                               name: "Test2",
                               uri: "otpauth://totp/SimpleLogin:john.doe%40example.com?secret=CKTQQJVWT5IXTGD&amp;issuer=SimpleLogin",
                               period: 30,
                               issuer: "SimpleLogin",
                               secret: "CKTQQJVWT5IXTGD",
                               type: .totp,
                               note: "Note"),
                  order: 1,
                  keyId: localKeyId),
            .init(entry: Entry(id: "id2",
                               name: "Test3",
                               uri: "otpauth://totp/SimpleLogin:john.doe%40example.com?secret=CKTQQJVWT5IXTGD&amp;issuer=SimpleLogin",
                               period: 30,
                               issuer: "SimpleLogin",
                               secret: "CKTQQJVWT5IXTGD",
                               type: .totp,
                               note: "Note"),
                  order: 2,
                  keyId: localKeyId),
            .init(entry: Entry(id: "id0",
                               name: "Test",
                               uri: "otpauth://totp/SimpleLogin:john.doe%40example.com?secret=CKTQQJVWT5IXTGD&amp;issuer=SimpleLogin",
                               period: 40,
                               issuer: "SimpleLogin",
                               secret: "CKTQQJVWT5IXTGD",
                               type: .totp,
                               note: "new note"),
                  order: 3,
                  keyId: localKeyId)
        ]
        
        
        try await sut.localUpsert(entries)
        
        let fetchedEntries = try await sut.getAllLocalEntries().decodedEntries

        // Assert
        #expect(fetchedEntries.first?.entry.id == "id0")

        #expect(fetchedEntries.last?.entry.id == "id3")
        
        try await sut.localReorder(reorderEntries)
        
        let reorderedfetchedEntries = try await sut.getAllLocalEntries().decodedEntries
        
        #expect(reorderedfetchedEntries.first?.entry.id == "id3")

        #expect(reorderedfetchedEntries.last?.entry.id == "id0")
    }

    // MARK: - Silent duplicate cleanup

    @Test("getAllLocalEntries returns entries when no duplicates exist")
    func getAllLocalEntries_noDuplicates_returnsEntries() async throws {
        let localKeyId = encryptionService.localEncryptionKeyId
        // swiftlint:disable:next line_length
        let entry = OrderedEntry(entry: Entry(id: "id1", name: "GitHub", uri: "otpauth://totp/GitHub:user?secret=CKTQQJVWT5IXTGD&issuer=GitHub&algorithm=SHA1&digits=6&period=30",
                                              period: 30, issuer: "GitHub", secret: "CKTQQJVWT5IXTGD",
                                              type: .totp, note: nil),
                                 order: 0, keyId: localKeyId)
        try await sut.localUpsert(entry)

        let result = try await sut.getAllLocalEntries()

        #expect(result.count == 1)
    }

    @Test("getAllLocalEntries silently cleans same-content duplicates")
    func getAllLocalEntries_withSameContentDuplicates_cleansUp() async throws {
        let localKeyId = encryptionService.localEncryptionKeyId
        // swiftlint:disable:next line_length
        let entry = OrderedEntry(entry: Entry(id: "dup-id", name: "GitHub", uri: "otpauth://totp/GitHub:user?secret=CKTQQJVWT5IXTGD&issuer=GitHub&algorithm=SHA1&digits=6&period=30",
                                              period: 30, issuer: "GitHub", secret: "CKTQQJVWT5IXTGD",
                                              type: .totp, note: nil),
                                 order: 0, keyId: localKeyId)
        try await sut.localUpsert(entry)
        try await injectDuplicate(forEntryId: "dup-id", withModifiedTime: Date.now.timeIntervalSince1970 - 100,
                                  encryptedData: encryptedData(for: entry))

        // Before cleanup, 2 raw entities exist
        let rawBefore = try await sut.getAllLocalEncryptedEntries().filter { $0.id == "dup-id" }
        #expect(rawBefore.count == 2)

        let result = try await sut.getAllLocalEntries()

        // After silent cleanup, only 1 entry returned
        #expect(result.count == 1)

        // Raw DB should also have only 1 entity now
        let rawAfter = try await sut.getAllLocalEncryptedEntries().filter { $0.id == "dup-id" }
        #expect(rawAfter.count == 1)
    }

    @Test("getAllLocalEntries keeps newest entry when cleaning same-content duplicates")
    func getAllLocalEntries_withDuplicates_keepsNewest() async throws {
        let localKeyId = encryptionService.localEncryptionKeyId
        let newerTime = Date.now.timeIntervalSince1970
        let olderTime = newerTime - 100

        let entry = OrderedEntry(entry: Entry(id: "dup-id", name: "GitHub",
                                              // swiftlint:disable:next line_length
                                              uri: "otpauth://totp/GitHub:user?secret=CKTQQJVWT5IXTGD&issuer=GitHub&algorithm=SHA1&digits=6&period=30",
                                              period: 30, issuer: "GitHub", secret: "CKTQQJVWT5IXTGD",
                                              type: .totp, note: nil),
                                 order: 0,
                                 modifiedTime: newerTime,
                                 keyId: localKeyId)
        try await sut.localUpsert(entry)
        try await injectDuplicate(forEntryId: "dup-id", withModifiedTime: olderTime,
                                  encryptedData: encryptedData(for: entry))

        let result = try await sut.getAllLocalEntries()

        #expect(result.count == 1)

        // The kept entry must be the newest one
        if case let .decrypted(_, kept) = result.first {
            #expect(kept.modifiedTime == newerTime)
        } else {
            Issue.record("Expected a decrypted entry")
        }
    }

    @Test("getAllLocalEntries silently cleans multiple independent duplicate groups")
    func getAllLocalEntries_multipleDuplicateGroups_cleansAll() async throws {
        let localKeyId = encryptionService.localEncryptionKeyId

        let entryA = OrderedEntry(entry: Entry(id: "a", name: "GitHub",
                                               // swiftlint:disable:next line_length
                                               uri: "otpauth://totp/GitHub?secret=CKTQQJVWT5IXTGD&algorithm=SHA1&digits=6&period=30",
                                               period: 30, issuer: "GitHub", secret: "CKTQQJVWT5IXTGD",
                                               type: .totp, note: nil),
                                  order: 0, keyId: localKeyId)
        let entryB = OrderedEntry(entry: Entry(id: "b", name: "Proton",
                                               // swiftlint:disable:next line_length
                                               uri: "otpauth://totp/Proton?secret=CKTQQJVWT5IXTGD&algorithm=SHA1&digits=6&period=30",
                                               period: 30, issuer: "Proton", secret: "CKTQQJVWT5IXTGD",
                                               type: .totp, note: nil),
                                  order: 1, keyId: localKeyId)
        try await sut.localUpsert([entryA, entryB])

        // Inject duplicates with valid encrypted data
        try await injectDuplicate(forEntryId: "a", withModifiedTime: Date.now.timeIntervalSince1970 - 50,
                                  encryptedData: encryptedData(for: entryA))
        try await injectDuplicate(forEntryId: "b", withModifiedTime: Date.now.timeIntervalSince1970 - 50,
                                  encryptedData: encryptedData(for: entryB))
        try await injectDuplicate(forEntryId: "b", withModifiedTime: Date.now.timeIntervalSince1970 - 100,
                                  encryptedData: encryptedData(for: entryB))

        let result = try await sut.getAllLocalEntries()

        // Only 2 unique entries remain after silent cleanup
        #expect(result.count == 2)
    }

    @Test("getAllLocalEntries deletes non-decryptable duplicates as fallback")
    func getAllLocalEntries_nonDecryptableDuplicate_deletesIt() async throws {
        let localKeyId = encryptionService.localEncryptionKeyId
        // swiftlint:disable:next line_length
        let entry = OrderedEntry(entry: Entry(id: "dup-id", name: "GitHub", uri: "otpauth://totp/GitHub:user?secret=CKTQQJVWT5IXTGD&issuer=GitHub&algorithm=SHA1&digits=6&period=30",
                                              period: 30, issuer: "GitHub", secret: "CKTQQJVWT5IXTGD",
                                              type: .totp, note: nil),
                                 order: 0, keyId: localKeyId)
        try await sut.localUpsert(entry)
        // Inject a non-decryptable duplicate (empty data, dummy key)
        try await injectDuplicate(forEntryId: "dup-id", olderThanCurrentBy: 100)

        let result = try await sut.getAllLocalEntries()

        #expect(result.count == 1)

        // Raw DB should also have only 1 entity
        let rawAfter = try await sut.getAllLocalEncryptedEntries().filter { $0.id == "dup-id" }
        #expect(rawAfter.count == 1)
    }

    @Test("localReorder succeeds when duplicate entries exist in DB")
    func localReorder_withDuplicates_succeeds() async throws {
        let localKeyId = encryptionService.localEncryptionKeyId
        let entries: [OrderedEntry] = [
            .init(entry: Entry(id: "id0", name: "First",
                               // swiftlint:disable:next line_length
                               uri: "otpauth://totp/First?secret=CKTQQJVWT5IXTGD&issuer=Test&algorithm=SHA1&digits=6&period=30",
                               period: 30, issuer: "Test", secret: "CKTQQJVWT5IXTGD",
                               type: .totp, note: nil),
                  order: 0, keyId: localKeyId),
            .init(entry: Entry(id: "id1", name: "Second",
                               // swiftlint:disable:next line_length
                               uri: "otpauth://totp/Second?secret=CKTQQJVWT5IXTGD&issuer=Test&algorithm=SHA1&digits=6&period=30",
                               period: 30, issuer: "Test", secret: "CKTQQJVWT5IXTGD",
                               type: .totp, note: nil),
                  order: 1, keyId: localKeyId)
        ]
        try await sut.localUpsert(entries)
        // Inject a duplicate for id0
        try await injectDuplicate(forEntryId: "id0", olderThanCurrentBy: 100)

        // Reorder: swap id1 to position 0, id0 to position 1
        let reorderEntries: [OrderedEntry] = [
            .init(entry: entries[1].entry, order: 0, keyId: localKeyId),
            .init(entry: entries[0].entry, order: 1, keyId: localKeyId)
        ]

        // Should not throw or silently return
        try await sut.localReorder(reorderEntries)

        let result = try await sut.getAllLocalEntries().decodedEntries
        #expect(result.first?.entry.id == "id1")
        #expect(result.last?.entry.id == "id0")
    }

    @Test("localReorder updates all DB copies including duplicates")
    func localReorder_withDuplicates_updatesAllCopies() async throws {
        let localKeyId = encryptionService.localEncryptionKeyId
        let entry = OrderedEntry(entry: Entry(id: "dup-id", name: "Test",
                                              // swiftlint:disable:next line_length
                                              uri: "otpauth://totp/Test?secret=CKTQQJVWT5IXTGD&issuer=Test&algorithm=SHA1&digits=6&period=30",
                                              period: 30, issuer: "Test", secret: "CKTQQJVWT5IXTGD",
                                              type: .totp, note: nil),
                                 order: 0, keyId: localKeyId)
        try await sut.localUpsert(entry)
        try await injectDuplicate(forEntryId: "dup-id", olderThanCurrentBy: 100)

        // Reorder to position 5
        let reorderEntry = OrderedEntry(entry: entry.entry, order: 5, keyId: localKeyId)
        try await sut.localReorder([reorderEntry])

        // Fetch ALL raw entities (including duplicates)
        let allEntities = try await sut.getAllLocalEncryptedEntries()
        let dupEntities = allEntities.filter { $0.id == "dup-id" }

        #expect(dupEntities.count == 2)
        // All copies should have the updated order
        for entity in dupEntities {
            #expect(entity.order == 5)
        }
    }

    @Test("localUpsert syncs order to duplicate copies so all copies stay consistent")
    func localUpsert_syncsOrderToDuplicates() async throws {
        let localKeyId = encryptionService.localEncryptionKeyId
        let newerTime = Date.now.timeIntervalSince1970
        let olderTime = newerTime - 100

        let entry = OrderedEntry(entry: Entry(id: "dup-id", name: "Test",
                                              // swiftlint:disable:next line_length
                                              uri: "otpauth://totp/Test?secret=CKTQQJVWT5IXTGD&issuer=Test&algorithm=SHA1&digits=6&period=30",
                                              period: 30, issuer: "Test", secret: "CKTQQJVWT5IXTGD",
                                              type: .totp, note: nil),
                                 order: 0, modifiedTime: newerTime, keyId: localKeyId)
        try await sut.localUpsert(entry)
        try await injectDuplicate(forEntryId: "dup-id", withModifiedTime: olderTime,
                                  encryptedData: encryptedData(for: entry))

        // Upsert with a new order and a remote modifiedTime older than the duplicate's
        // This simulates sync writing remote data where the remote time is older
        let remoteTime = olderTime - 50 // Even older than the duplicate
        let updatedEntry = OrderedEntry(entry: entry.entry, keyId: localKeyId, remoteId: nil,
                                        order: 5, syncState: .synced,
                                        modifiedTime: remoteTime,
                                        revision: 1, contentFormatVersion: 1)
        try await sut.localUpsert(updatedEntry)

        // ALL copies (including duplicate) should have order=5
        let allEntities = try await sut.getAllLocalEncryptedEntries()
        let dupEntities = allEntities.filter { $0.id == "dup-id" }
        #expect(dupEntities.count == 2)
        for entity in dupEntities {
            #expect(entity.order == 5)
        }
    }

    @Test("localUpsert with updated order persists order to DB via update(with:)")
    func localUpsert_updatesOrder() async throws {
        let localKeyId = encryptionService.localEncryptionKeyId
        let entry = OrderedEntry(entry: Entry(id: "order-id", name: "OrderTest",
                                              uri: "otpauth://totp/OrderTest?secret=CKTQQJVWT5IXTGD&issuer=Test&algorithm=SHA1&digits=6&period=30",
                                              period: 30, issuer: "Test", secret: "CKTQQJVWT5IXTGD",
                                              type: .totp, note: nil),
                                 order: 0, keyId: localKeyId)
        try await sut.localUpsert(entry)

        // Upsert again with a new order (simulates sync writing remote order)
        let updatedEntry = OrderedEntry(entry: entry.entry, keyId: localKeyId, remoteId: nil,
                                        order: 7, syncState: .synced,
                                        modifiedTime: Date.now.timeIntervalSince1970,
                                        revision: 1, contentFormatVersion: 1)
        try await sut.localUpsert(updatedEntry)

        let allEntities = try await sut.getAllLocalEncryptedEntries()
        let entity = try #require(allEntities.first(where: { $0.id == "order-id" }))
        #expect(entity.order == 7)
    }

    // MARK: - Remote update routing for entries with empty remoteId

    @Test("localUpdate returns OrderedEntry with nil remoteId when entity has empty remoteId")
    func localUpdate_emptyEntityRemoteId_returnsNilRemoteId() async throws {
        let entryId = "empty-remote-id-entry"
        let localKeyId = encryptionService.localEncryptionKeyId
        let entry = Entry(id: entryId, name: "Test",
                          uri: "otpauth://totp/Test?secret=CKTQQJVWT5IXTGD&issuer=Test&algorithm=SHA1&digits=6&period=30",
                          period: 30, issuer: "Test", secret: "CKTQQJVWT5IXTGD",
                          type: .totp, note: nil)

        let encryptedData = try encryptionService.encrypt(entry: entry, keyId: localKeyId)
        let entity = EncryptedEntryEntity(id: entryId,
                                          encryptedData: encryptedData,
                                          remoteId: "",
                                          keyId: localKeyId,
                                          order: 0,
                                          syncState: .unsynced,
                                          creationDate: Date.now.timeIntervalSince1970,
                                          modifiedTime: Date.now.timeIntervalSince1970,
                                          flags: 0,
                                          contentFormatVersion: 1,
                                          revision: 1)
        try await localDataManager.persistentStorage.batchSave(content: [entity])

        let orderedEntry = OrderedEntry(entry: entry, order: 0, keyId: localKeyId)
        let result = try #require(await sut.localUpdate(orderedEntry))

        #expect(result.remoteId == nil)
    }

    @Test("remoteUpdate throws missingRemoteId for empty remoteId and does not call API")
    func remoteUpdate_emptyRemoteId_throwsAndDoesNotHitAPI() async throws {
        store.set("test-remote-key-id", forKey: AppConstants.Settings.remoteEncryptionKeyId)

        let localKeyId = encryptionService.localEncryptionKeyId
        let entry = Entry(id: "id-empty", name: "Test",
                          uri: "otpauth://totp/Test?secret=CKTQQJVWT5IXTGD&issuer=Test&algorithm=SHA1&digits=6&period=30",
                          period: 30, issuer: "Test", secret: "CKTQQJVWT5IXTGD",
                          type: .totp, note: nil)
        let orderedEntry = OrderedEntry(entry: entry,
                                        keyId: localKeyId,
                                        remoteId: "",
                                        order: 0,
                                        modifiedTime: Date.now.timeIntervalSince1970,
                                        revision: 1,
                                        contentFormatVersion: 1)

        await #expect(throws: AuthError.self) {
            _ = try await sut.remoteUpdate(entry: orderedEntry)
        }

        #expect(apiClient.lastUpdateEntryId == nil)
        #expect(!apiClient.calledMethods.contains("update(entryId:request:)"))
    }

    @Test("completeUpdate routes unsynced entry to remoteSave and updates local remoteId")
    func completeUpdate_unsyncedEntry_routesToRemoteSave() async throws {
        let entryId = "unsynced-entry-id"
        let assignedRemoteId = "be-assigned-remote-id"
        let remoteKeyId = "test-remote-key-id"

        userSession.isAuthenticatedWithUserData.send(true)
        let remoteKey = encryptionService.generateKey()
        try encryptionService.saveUserRemoteKey(keyId: remoteKeyId, remoteKey: remoteKey)
        store.set(remoteKeyId, forKey: AppConstants.Settings.remoteEncryptionKeyId)

        apiClient.storeEntriesResult = .success([
            RemoteEncryptedEntry(entryID: assignedRemoteId,
                                 authenticatorKeyID: remoteKeyId,
                                 revision: 1,
                                 contentFormatVersion: 1,
                                 content: "data",
                                 flags: 0,
                                 createTime: 123_456,
                                 modifyTime: 123_456)
        ])

        let localKeyId = encryptionService.localEncryptionKeyId
        let entry = Entry(id: entryId, name: "Test",
                          uri: "otpauth://totp/Test?secret=CKTQQJVWT5IXTGD&issuer=Test&algorithm=SHA1&digits=6&period=30",
                          period: 30, issuer: "Test", secret: "CKTQQJVWT5IXTGD",
                          type: .totp, note: nil)
        let initialOrderedEntry = OrderedEntry(entry: entry, order: 0, keyId: localKeyId)
        try await sut.localUpsert([initialOrderedEntry])

        let updatedEntry = Entry(id: entryId, name: "Updated", uri: entry.uri,
                                 period: entry.period, issuer: entry.issuer,
                                 secret: entry.secret, type: entry.type, note: nil)
        let updatedOrderedEntry = OrderedEntry(entry: updatedEntry, order: 0, keyId: localKeyId)

        try await sut.completeUpdate(entry: updatedOrderedEntry, oldEntry: initialOrderedEntry)

        #expect(apiClient.calledMethods.contains("storeEntries(request:)"))
        #expect(!apiClient.calledMethods.contains("update(entryId:request:)"))
        #expect(apiClient.lastUpdateEntryId == nil)

        let allEntities = try await sut.getAllLocalEncryptedEntries()
        let persisted = try #require(allEntities.first(where: { $0.id == entryId }))
        #expect(persisted.remoteId == assignedRemoteId)
        #expect(persisted.syncState == .synced)
    }

    @Test("completeUpdate routes synced entry to remoteUpdate (regression guard)")
    func completeUpdate_syncedEntry_routesToRemoteUpdate() async throws {
        let entryId = "synced-entry-id"
        let validRemoteId = "valid-remote-id"
        let remoteKeyId = "test-remote-key-id"

        userSession.isAuthenticatedWithUserData.send(true)
        let remoteKey = encryptionService.generateKey()
        try encryptionService.saveUserRemoteKey(keyId: remoteKeyId, remoteKey: remoteKey)
        store.set(remoteKeyId, forKey: AppConstants.Settings.remoteEncryptionKeyId)

        apiClient.updateResult = .success(
            RemoteEncryptedEntry(entryID: validRemoteId,
                                 authenticatorKeyID: remoteKeyId,
                                 revision: 2,
                                 contentFormatVersion: 1,
                                 content: "data",
                                 flags: 0,
                                 createTime: 123_456,
                                 modifyTime: 123_457)
        )

        let localKeyId = encryptionService.localEncryptionKeyId
        let entry = Entry(id: entryId, name: "Test",
                          uri: "otpauth://totp/Test?secret=CKTQQJVWT5IXTGD&issuer=Test&algorithm=SHA1&digits=6&period=30",
                          period: 30, issuer: "Test", secret: "CKTQQJVWT5IXTGD",
                          type: .totp, note: nil)
        let encryptedData = try encryptionService.encrypt(entry: entry, keyId: localKeyId)
        let entity = EncryptedEntryEntity(id: entryId,
                                          encryptedData: encryptedData,
                                          remoteId: validRemoteId,
                                          keyId: localKeyId,
                                          order: 0,
                                          syncState: .synced,
                                          creationDate: Date.now.timeIntervalSince1970,
                                          modifiedTime: Date.now.timeIntervalSince1970,
                                          flags: 0,
                                          contentFormatVersion: 1,
                                          revision: 1)
        try await localDataManager.persistentStorage.batchSave(content: [entity])

        let now = Date.now.timeIntervalSince1970
        let oldOrderedEntry = OrderedEntry(entry: entry, keyId: localKeyId,
                                           remoteId: validRemoteId, order: 0,
                                           syncState: .synced, modifiedTime: now,
                                           revision: 1, contentFormatVersion: 1)
        let updatedEntry = Entry(id: entryId, name: "Updated", uri: entry.uri,
                                 period: entry.period, issuer: entry.issuer,
                                 secret: entry.secret, type: entry.type, note: nil)
        let updatedOrderedEntry = OrderedEntry(entry: updatedEntry, keyId: localKeyId,
                                               remoteId: validRemoteId, order: 0,
                                               syncState: .synced, modifiedTime: now,
                                               revision: 1, contentFormatVersion: 1)

        try await sut.completeUpdate(entry: updatedOrderedEntry, oldEntry: oldOrderedEntry)

        #expect(apiClient.calledMethods.contains("update(entryId:request:)"))
        #expect(!apiClient.calledMethods.contains("storeEntries(request:)"))
        #expect(apiClient.lastUpdateEntryId == validRemoteId)
    }
}

// MARK: - Duplicate injection helpers

private extension EntryRepositoryTests {
    /// Injects a raw duplicate entity into the persistence layer for the given entry ID,
    /// with a `modifiedTime` offset from the current time.
    func injectDuplicate(forEntryId entryId: String, olderThanCurrentBy offset: TimeInterval) async throws {
        let storage = localDataManager.persistentStorage
        let entity = EncryptedEntryEntity(id: entryId,
                                          encryptedData: Data(),
                                          remoteId: "",
                                          keyId: "dummy-key",
                                          order: 0,
                                          syncState: .unsynced,
                                          creationDate: Date.now.timeIntervalSince1970,
                                          modifiedTime: Date.now.timeIntervalSince1970 - offset)
        try await storage.batchSave(content: [entity])
    }

    /// Injects a raw duplicate entity with the given `modifiedTime` and encrypted data.
    func injectDuplicate(forEntryId entryId: String,
                         withModifiedTime modifiedTime: TimeInterval,
                         encryptedData data: Data) async throws {
        let storage = localDataManager.persistentStorage
        let entity = EncryptedEntryEntity(id: entryId,
                                          encryptedData: data,
                                          remoteId: "",
                                          keyId: encryptionService.localEncryptionKeyId,
                                          order: 0,
                                          syncState: .unsynced,
                                          creationDate: Date.now.timeIntervalSince1970,
                                          modifiedTime: modifiedTime)
        try await storage.batchSave(content: [entity])
    }

    /// Returns the encrypted data for the given `OrderedEntry` using the shared encryption service.
    func encryptedData(for entry: OrderedEntry) throws -> Data {
        try encryptionService.encrypt(entry: entry.entry, keyId: entry.keyId ?? encryptionService.localEncryptionKeyId)
    }
}

extension OrderedEntry {
    init(entry: Entry, order: Int, keyId: String) {
        self.init(entry: entry, keyId: keyId, remoteId: nil, order: order, modifiedTime: Date.now.timeIntervalSince1970, revision: 1, contentFormatVersion: 1)
    }

    init(entry: Entry, order: Int, modifiedTime: TimeInterval, keyId: String) {
        self.init(entry: entry, keyId: keyId, remoteId: nil, order: order, modifiedTime: modifiedTime, revision: 1, contentFormatVersion: 1)
    }
}
