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

import Foundation
import SimplyPersist
import Testing
import Models
import SwiftData
@testable import DataLayer

enum MockKeychainError: Error {
    case itemNotFound
    case typeMismatch
}

@Suite(.tags(.repository))
struct EntryRepositoryTests {
    let sut: EntryRepositoryProtocol
    let encryptionService: any EncryptionServicing
    let localDataManager: MockLocalDataManager

    init() throws {
        let persistenceService = try PersistenceService(with: ModelConfiguration(for: EncryptedEntryEntity.self,
                                                                                 isStoredInMemoryOnly: true))

        localDataManager = MockLocalDataManager(persistentStorage: persistenceService)
        encryptionService = EncryptionService(keysProvider: MockKeyProvider(),
                                              logger: MockLogger())
        sut = EntryRepository(localDataManager: localDataManager,
                              encryptionService: encryptionService,
                              apiClient: MockAPIClient(),
                              userSessionManager: MockUserSessionTooling(),
                              store: UserDefaults(),
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
        
        var entries = try await sut.getAllLocalEntries().entries.decodedEntries

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
        entries = try await sut.getAllLocalEntries().entries.decodedEntries

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
        
        let fetchedEntries = try await sut.getAllLocalEntries().entries

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
        
        let fetchedEntries = try await sut.getAllLocalEntries().entries

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
        
        var fetchedEntries = try await sut.getAllLocalEntries().entries

        // Assert
        #expect(fetchedEntries.count == 2)

        try await sut.localRemoves(["id2"])

         fetchedEntries = try await sut.getAllLocalEntries().entries

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
        
        let fetchedEntries = try await sut.getAllLocalEntries().entries.decodedEntries

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
        
        let fetchedEntries = try await sut.getAllLocalEntries().entries.decodedEntries

        // Assert
        #expect(fetchedEntries.first?.entry.id == "id0")

        #expect(fetchedEntries.last?.entry.id == "id3")
        
        try await sut.localReorder(reorderEntries)
        
        let reorderedfetchedEntries = try await sut.getAllLocalEntries().entries.decodedEntries
        
        #expect(reorderedfetchedEntries.first?.entry.id == "id3")

        #expect(reorderedfetchedEntries.last?.entry.id == "id0")
    }

    // MARK: - Duplicate detection

    @Test("getAllLocalEntries returns zero duplicate count when no duplicates exist")
    func getAllLocalEntries_noDuplicates_returnsZeroDuplicateCount() async throws {
        let localKeyId = encryptionService.localEncryptionKeyId
        let entry = OrderedEntry(entry: Entry(id: "id1", name: "GitHub", uri: "otpauth://totp/GitHub:user?secret=CKTQQJVWT5IXTGD&issuer=GitHub&algorithm=SHA1&digits=6&period=30",
                                              period: 30, issuer: "GitHub", secret: "CKTQQJVWT5IXTGD",
                                              type: .totp, note: nil),
                                 order: 0, keyId: localKeyId)
        try await sut.localUpsert(entry)

        let result = try await sut.getAllLocalEntries()

        #expect(result.duplicateCount == 0)
        #expect(result.entries.count == 1)
    }

    @Test("getAllLocalEntries returns correct duplicate count when duplicates exist")
    func getAllLocalEntries_withDuplicates_returnsDuplicateCount() async throws {
        let localKeyId = encryptionService.localEncryptionKeyId
        let entry = OrderedEntry(entry: Entry(id: "dup-id", name: "GitHub", uri: "otpauth://totp/GitHub:user?secret=CKTQQJVWT5IXTGD&issuer=GitHub&algorithm=SHA1&digits=6&period=30",
                                              period: 30, issuer: "GitHub", secret: "CKTQQJVWT5IXTGD",
                                              type: .totp, note: nil),
                                 order: 0, keyId: localKeyId)
        try await sut.localUpsert(entry)
        try await injectDuplicate(forEntryId: "dup-id", olderThanCurrentBy: 100)

        let result = try await sut.getAllLocalEntries()

        #expect(result.duplicateCount == 1)
    }

    @Test("getAllLocalEntries returns only one entry per ID when duplicates exist")
    func getAllLocalEntries_withDuplicates_deduplicatesKeepingNewest() async throws {
        let localKeyId = encryptionService.localEncryptionKeyId
        let newerTime = Date.now.timeIntervalSince1970
        let olderTime = newerTime - 100

        let entry = OrderedEntry(entry: Entry(id: "dup-id", name: "GitHub",
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

        // Only the deduplicated entry should be returned
        #expect(result.entries.count == 1)
        #expect(result.duplicateCount == 1)

        // The kept entry must be the newest one
        if case .decrypted(let kept) = result.entries.first {
            #expect(kept.modifiedTime == newerTime)
        } else {
            Issue.record("Expected a decrypted entry")
        }
    }

    @Test("getAllLocalEntries handles multiple independent duplicates")
    func getAllLocalEntries_multipleDuplicateGroups_returnsCorrectCounts() async throws {
        let localKeyId = encryptionService.localEncryptionKeyId

        let entryA = OrderedEntry(entry: Entry(id: "a", name: "GitHub",
                                               uri: "otpauth://totp/GitHub?secret=CKTQQJVWT5IXTGD&algorithm=SHA1&digits=6&period=30",
                                               period: 30, issuer: "GitHub", secret: "CKTQQJVWT5IXTGD",
                                               type: .totp, note: nil),
                                  order: 0, keyId: localKeyId)
        let entryB = OrderedEntry(entry: Entry(id: "b", name: "Proton",
                                               uri: "otpauth://totp/Proton?secret=CKTQQJVWT5IXTGD&algorithm=SHA1&digits=6&period=30",
                                               period: 30, issuer: "Proton", secret: "CKTQQJVWT5IXTGD",
                                               type: .totp, note: nil),
                                  order: 1, keyId: localKeyId)
        try await sut.localUpsert([entryA, entryB])

        // Inject one duplicate for "a" and two duplicates for "b"
        try await injectDuplicate(forEntryId: "a", olderThanCurrentBy: 50)
        try await injectDuplicate(forEntryId: "b", olderThanCurrentBy: 50)
        try await injectDuplicate(forEntryId: "b", olderThanCurrentBy: 100)

        let result = try await sut.getAllLocalEntries()

        #expect(result.entries.count == 2)
        #expect(result.duplicateCount == 3) // 1 extra for "a", 2 extra for "b"
    }

    @Test("getDuplicateEntryGroups returns empty when no duplicates")
    func getDuplicateEntryGroups_noDuplicates_returnsEmpty() async throws {
        let localKeyId = encryptionService.localEncryptionKeyId
        let entry = OrderedEntry(entry: Entry(id: "id1", name: "GitHub",
                                              uri: "otpauth://totp/GitHub?secret=CKTQQJVWT5IXTGD&algorithm=SHA1&digits=6&period=30",
                                              period: 30, issuer: "GitHub", secret: "CKTQQJVWT5IXTGD",
                                              type: .totp, note: nil),
                                 order: 0, keyId: localKeyId)
        try await sut.localUpsert(entry)

        let groups = try await sut.getDuplicateEntryGroups()

        #expect(groups.isEmpty)
    }

    @Test("getDuplicateEntryGroups returns one group with all copies")
    func getDuplicateEntryGroups_withDuplicates_returnsGroup() async throws {
        let localKeyId = encryptionService.localEncryptionKeyId
        let entry = OrderedEntry(entry: Entry(id: "dup-id", name: "GitHub",
                                              uri: "otpauth://totp/GitHub?secret=CKTQQJVWT5IXTGD&algorithm=SHA1&digits=6&period=30",
                                              period: 30, issuer: "GitHub", secret: "CKTQQJVWT5IXTGD",
                                              type: .totp, note: nil),
                                 order: 0, keyId: localKeyId)
        try await sut.localUpsert(entry)
        try await injectDuplicate(forEntryId: "dup-id", olderThanCurrentBy: 100)

        let groups = try await sut.getDuplicateEntryGroups()

        #expect(groups.count == 1)
        #expect(groups.first?.entryId == "dup-id")
        #expect(groups.first?.entries.count == 2)
    }

    @Test("getDuplicateEntryGroups marks newest entry as currently active")
    func getDuplicateEntryGroups_marksNewestEntryAsCurrentlyActive() async throws {
        let localKeyId = encryptionService.localEncryptionKeyId
        let newerTime = Date.now.timeIntervalSince1970
        let olderTime = newerTime - 100

        let entry = OrderedEntry(entry: Entry(id: "dup-id", name: "GitHub",
                                              uri: "otpauth://totp/GitHub?secret=CKTQQJVWT5IXTGD&algorithm=SHA1&digits=6&period=30",
                                              period: 30, issuer: "GitHub", secret: "CKTQQJVWT5IXTGD",
                                              type: .totp, note: nil),
                                 order: 0, modifiedTime: newerTime, keyId: localKeyId)
        try await sut.localUpsert(entry)
        try await injectDuplicate(forEntryId: "dup-id", withModifiedTime: olderTime,
                                  encryptedData: encryptedData(for: entry))

        let groups = try await sut.getDuplicateEntryGroups()

        let entries = try #require(groups.first?.entries)
        let activeEntry = try #require(entries.first(where: { $0.isCurrentlyActive }))
        let inactiveEntry = try #require(entries.first(where: { !$0.isCurrentlyActive }))

        #expect(activeEntry.modifiedTime == newerTime)
        #expect(inactiveEntry.modifiedTime == olderTime)
    }

    @Test("deleteLocalDuplicate removes only the matching entity")
    func deleteLocalDuplicate_removesMatchingEntity() async throws {
        let localKeyId = encryptionService.localEncryptionKeyId
        let newerTime = Date.now.timeIntervalSince1970
        let olderTime = newerTime - 100

        let entry = OrderedEntry(entry: Entry(id: "dup-id", name: "GitHub",
                                              uri: "otpauth://totp/GitHub?secret=CKTQQJVWT5IXTGD&algorithm=SHA1&digits=6&period=30",
                                              period: 30, issuer: "GitHub", secret: "CKTQQJVWT5IXTGD",
                                              type: .totp, note: nil),
                                 order: 0, modifiedTime: newerTime, keyId: localKeyId)
        try await sut.localUpsert(entry)
        try await injectDuplicate(forEntryId: "dup-id", withModifiedTime: olderTime,
                                  encryptedData: encryptedData(for: entry))

        // Verify we have 2 entities before deletion
        var result = try await sut.getAllLocalEntries()
        #expect(result.duplicateCount == 1)

        // Delete the older duplicate
        try await sut.deleteLocalDuplicate(entryId: "dup-id", modifiedTime: olderTime)

        result = try await sut.getAllLocalEntries()
        #expect(result.duplicateCount == 0)
        #expect(result.entries.count == 1)
    }

    @Test("deleteLocalDuplicate does not affect other entries")
    func deleteLocalDuplicate_doesNotAffectOtherEntries() async throws {
        let localKeyId = encryptionService.localEncryptionKeyId
        let newerTime = Date.now.timeIntervalSince1970
        let olderTime = newerTime - 100

        let entryA = OrderedEntry(entry: Entry(id: "a", name: "GitHub",
                                               uri: "otpauth://totp/GitHub?secret=CKTQQJVWT5IXTGD&algorithm=SHA1&digits=6&period=30",
                                               period: 30, issuer: "GitHub", secret: "CKTQQJVWT5IXTGD",
                                               type: .totp, note: nil),
                                  order: 0, modifiedTime: newerTime, keyId: localKeyId)
        let entryB = OrderedEntry(entry: Entry(id: "b", name: "Proton",
                                               uri: "otpauth://totp/Proton?secret=CKTQQJVWT5IXTGD&algorithm=SHA1&digits=6&period=30",
                                               period: 30, issuer: "Proton", secret: "CKTQQJVWT5IXTGD",
                                               type: .totp, note: nil),
                                  order: 1, keyId: localKeyId)
        try await sut.localUpsert([entryA, entryB])
        try await injectDuplicate(forEntryId: "a", withModifiedTime: olderTime,
                                  encryptedData: encryptedData(for: entryA))

        try await sut.deleteLocalDuplicate(entryId: "a", modifiedTime: olderTime)

        let result = try await sut.getAllLocalEntries()

        // Both logical entries survive; duplicate is gone
        #expect(result.entries.count == 2)
        #expect(result.duplicateCount == 0)
    }

    @Test("deleteLocalDuplicate does not delete the active entry when only older copy is targeted")
    func deleteLocalDuplicate_doesNotDeleteActiveEntry() async throws {
        let localKeyId = encryptionService.localEncryptionKeyId
        let newerTime = Date.now.timeIntervalSince1970
        let olderTime = newerTime - 100

        let entry = OrderedEntry(entry: Entry(id: "dup-id", name: "GitHub",
                                              uri: "otpauth://totp/GitHub?secret=CKTQQJVWT5IXTGD&algorithm=SHA1&digits=6&period=30",
                                              period: 30, issuer: "GitHub", secret: "CKTQQJVWT5IXTGD",
                                              type: .totp, note: nil),
                                 order: 0, modifiedTime: newerTime, keyId: localKeyId)
        try await sut.localUpsert(entry)
        try await injectDuplicate(forEntryId: "dup-id", withModifiedTime: olderTime,
                                  encryptedData: encryptedData(for: entry))

        // Delete the OLD copy (not the active one)
        try await sut.deleteLocalDuplicate(entryId: "dup-id", modifiedTime: olderTime)

        let result = try await sut.getAllLocalEntries()
        #expect(result.entries.count == 1)

        // Verify the remaining entry is the newer (active) one
        if case .decrypted(let kept) = result.entries.first {
            #expect(kept.modifiedTime == newerTime)
        } else {
            Issue.record("Expected a decrypted entry")
        }
    }
}

// MARK: - Duplicate injection helpers

private extension EntryRepositoryTests {
    /// Injects a raw duplicate entity into the persistence layer for the given entry ID,
    /// with a `modifiedTime` offset from the current time.
    func injectDuplicate(forEntryId entryId: String, olderThanCurrentBy offset: TimeInterval) async throws {
        let storage = await localDataManager.persistentStorage
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
        let storage = await localDataManager.persistentStorage
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
