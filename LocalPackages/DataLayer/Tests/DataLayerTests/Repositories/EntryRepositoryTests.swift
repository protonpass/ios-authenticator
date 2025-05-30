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
    
    init() throws {
        let persistenceService = try PersistenceService(with: ModelConfiguration(for: EncryptedEntryEntity.self,
                                                                                 isStoredInMemoryOnly: true))
        
        encryptionService = EncryptionService(keychain: MockKeychainService(),
                                                                                  keysProvider: MockKeyProvider(),
                                                                                    logger: MockLogger())
        sut = EntryRepository(persistentStorage: persistenceService,
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
{"version":1,"entries":[{"id":"id","content":{"uri":"otpauth://totp/john.doe@example.com?secret=CKTQQJVWT5IXTGD&issuer=SimpleLogin&algorithm=SHA1&digits=6&period=30","entry_type":"Totp","name":"john.doe@example.com"},"note":"Note"}]}
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
                                               note: "Note"), order:1, keyId: localKeyId)
       
        try await sut.localUpsert(entry2)
        entries = try await sut.getAllLocalEntries().decodedEntries

        // Assert
        #expect(entries.count == 2)
    }
    
    @Test("Test saving mutiple entry in db")
    func savingArrayOfEntry() async throws {
        let localKeyId = encryptionService.localEncryptionKeyId

        let entries: [OrderedEntry] = [ .init(entry: Entry(id: "id",
                              name: "Test",
                              uri: "otpauth://totp/SimpleLogin:john.doe%40example.com?secret=CKTQQJVWT5IXTGD&amp;issuer=SimpleLogin",
                              period: 40,
                              issuer: "SimpleLogin",
                              secret: "CKTQQJVWT5IXTGD",
                              type: .totp,
                              note: "Note"),
                                              order: 0, keyId: localKeyId
                                               ),
                                        .init(  entry: Entry(id: "id2",
                              name: "Test2",
                              uri: "otpauth://totp/SimpleLogin:john.doe%40example.com?secret=CKTQQJVWT5IXTGD&amp;issuer=SimpleLogin",
                              period: 30,
                              issuer: "SimpleLogin",
                              secret: "CKTQQJVWT5IXTGD",
                              type: .totp,
                                                             note: "Note"), order:1, keyId: localKeyId),
                                        .init(  entry: Entry(id: "id3",
                              name: "Test3",
                              uri: "otpauth://totp/SimpleLogin:john.doe%40example.com?secret=CKTQQJVWT5IXTGD&amp;issuer=SimpleLogin",
                              period: 30,
                              issuer: "SimpleLogin",
                              secret: "CKTQQJVWT5IXTGD",
                              type: .totp,
                                                             note: "Note"), order: 2, keyId: localKeyId)
        ]
        
        try await sut.localUpsert(entries)
        
        let fetchedEntries = try await sut.getAllLocalEntries()

        // Assert
        #expect(fetchedEntries.count == 3)
    }
    
    @Test("Test removing all entries in db")
    func removingAllEntries() async throws {
        let localKeyId = encryptionService.localEncryptionKeyId

        let entries: [OrderedEntry] = [ .init(entry:  Entry(id: "id",
                                                            name: "Test",
                                                            uri: "otpauth://totp/SimpleLogin:john.doe%40example.com?secret=CKTQQJVWT5IXTGD&amp;issuer=SimpleLogin",
                                                            period: 40,
                                                            issuer: "SimpleLogin",
                                                            secret: "CKTQQJVWT5IXTGD",
                                                            type: .totp,
                                                            note: "Note"), order: 0, keyId: localKeyId),
                                        .init(entry:  Entry(id: "id2",
                              name: "Test2",
                              uri: "otpauth://totp/SimpleLogin:john.doe%40example.com?secret=CKTQQJVWT5IXTGD&amp;issuer=SimpleLogin",
                              period: 30,
                              issuer: "SimpleLogin",
                              secret: "CKTQQJVWT5IXTGD",
                              type: .totp,
                                                            note: "Note"), order:1, keyId: localKeyId),
                                        .init(entry:  Entry(id: "id3",
                              name: "Test3",
                              uri: "otpauth://totp/SimpleLogin:john.doe%40example.com?secret=CKTQQJVWT5IXTGD&amp;issuer=SimpleLogin",
                              period: 30,
                              issuer: "SimpleLogin",
                              secret: "CKTQQJVWT5IXTGD",
                              type: .totp,
                                                            note: "Note"), order: 2, keyId: localKeyId),
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

        let entries:[OrderedEntry] = [.init(entry:  Entry(id: "id",
                              name: "Test",
                              uri: "otpauth://totp/SimpleLogin:john.doe%40example.com?secret=CKTQQJVWT5IXTGD&amp;issuer=SimpleLogin",
                              period: 40,
                              issuer: "SimpleLogin",
                              secret: "CKTQQJVWT5IXTGD",
                              type: .totp,
                                                          note: "Note"), order: 0, keyId: localKeyId),
                                      .init(entry:  Entry(id: "id2",
                              name: "Test2",
                              uri: "otpauth://totp/SimpleLogin:john.doe%40example.com?secret=CKTQQJVWT5IXTGD&amp;issuer=SimpleLogin",
                              period: 30,
                              issuer: "SimpleLogin",
                              secret: "CKTQQJVWT5IXTGD",
                              type: .totp,
                                                          note: "Note"), order: 1, keyId: localKeyId),
                                      .init(entry:   Entry(id: "id3",
                              name: "Test3",
                              uri: "otpauth://totp/SimpleLogin:john.doe%40example.com?secret=CKTQQJVWT5IXTGD&amp;issuer=SimpleLogin",
                              period: 30,
                              issuer: "SimpleLogin",
                              secret: "CKTQQJVWT5IXTGD",
                              type: .totp,
                                                           note: "Note"), order: 2, keyId: localKeyId),
        ]
        
       
        try await sut.localUpsert(entries)
        try await sut.localRemove(entries.first!.entry)
        
        var fetchedEntries = try await sut.getAllLocalEntries()

        // Assert
        #expect(fetchedEntries.count == 2)
        
        try await sut.localRemove("id2")
        
         fetchedEntries = try await sut.getAllLocalEntries()

        // Assert
        #expect(fetchedEntries.count == 1)
    }

    @Test("Test updating one entry from db")
    func updateOneEntry() async throws {
        let localKeyId = encryptionService.localEncryptionKeyId

        let entries:[OrderedEntry] = [.init(entry:  Entry(id: "id",
                              name: "Test",
                              uri: "otpauth://totp/SimpleLogin:john.doe%40example.com?secret=CKTQQJVWT5IXTGD&amp;issuer=SimpleLogin",
                              period: 40,
                              issuer: "SimpleLogin",
                              secret: "CKTQQJVWT5IXTGD",
                              type: .totp,
                                                          note: "Note"),order: 0, keyId: localKeyId),
                                      .init(entry:  Entry(id: "id2",
                              name: "Test2",
                              uri: "otpauth://totp/SimpleLogin:john.doe%40example.com?secret=CKTQQJVWT5IXTGD&amp;issuer=SimpleLogin",
                              period: 30,
                              issuer: "SimpleLogin",
                              secret: "CKTQQJVWT5IXTGD",
                              type: .totp,
                                                          note: "Note"), order: 1, keyId: localKeyId),
                                      .init(entry: Entry(id: "id3",
                              name: "Test3",
                              uri: "otpauth://totp/SimpleLogin:john.doe%40example.com?secret=CKTQQJVWT5IXTGD&amp;issuer=SimpleLogin",
                              period: 30,
                              issuer: "SimpleLogin",
                              secret: "CKTQQJVWT5IXTGD",
                              type: .totp,
                                                         note: "Note"),order: 2, keyId: localKeyId)
        ]
        
        let newEntry1 =  OrderedEntry(entry: Entry(id: "id",
                              name: "Test",
                              uri: "otpauth://totp/SimpleLogin:john.doe%40example.com?secret=CKTQQJVWT5IXTGD&amp;issuer=SimpleLogin",
                              period: 40,
                              issuer: "SimpleLogin",
                              secret: "CKTQQJVWT5IXTGD",
                              type: .totp,
                                                   note: "new note"), order: 3, keyId: localKeyId)
        
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

        let entries:[OrderedEntry] = [.init(entry:  Entry(id: "id0",
                              name: "Test",
                              uri: "otpauth://totp/SimpleLogin:john.doe%40example.com?secret=CKTQQJVWT5IXTGD&amp;issuer=SimpleLogin",
                              period: 40,
                              issuer: "SimpleLogin",
                              secret: "CKTQQJVWT5IXTGD",
                              type: .totp,
                                                          note: "Note"),order: 0, keyId: localKeyId),
                                      .init(entry:  Entry(id: "id1",
                              name: "Test2",
                              uri: "otpauth://totp/SimpleLogin:john.doe%40example.com?secret=CKTQQJVWT5IXTGD&amp;issuer=SimpleLogin",
                              period: 30,
                              issuer: "SimpleLogin",
                              secret: "CKTQQJVWT5IXTGD",
                              type: .totp,
                                                          note: "Note"), order: 1, keyId: localKeyId),
                                      .init(entry: Entry(id: "id2",
                              name: "Test3",
                              uri: "otpauth://totp/SimpleLogin:john.doe%40example.com?secret=CKTQQJVWT5IXTGD&amp;issuer=SimpleLogin",
                              period: 30,
                              issuer: "SimpleLogin",
                              secret: "CKTQQJVWT5IXTGD",
                              type: .totp,
                                                         note: "Note"),order: 2, keyId: localKeyId),
                                      OrderedEntry(entry: Entry(id: "id3",
                                                            name: "Test",
                                                            uri: "otpauth://totp/SimpleLogin:john.doe%40example.com?secret=CKTQQJVWT5IXTGD&amp;issuer=SimpleLogin",
                                                            period: 40,
                                                            issuer: "SimpleLogin",
                                                            secret: "CKTQQJVWT5IXTGD",
                                                            type: .totp,
                                                                note: "new note"), order: 3, keyId: localKeyId)
        ]
        
        let reorderEntries:[OrderedEntry] = [.init(entry:  Entry(id: "id3",
                              name: "Test",
                              uri: "otpauth://totp/SimpleLogin:john.doe%40example.com?secret=CKTQQJVWT5IXTGD&amp;issuer=SimpleLogin",
                              period: 40,
                              issuer: "SimpleLogin",
                              secret: "CKTQQJVWT5IXTGD",
                              type: .totp,
                                                                 note: "Note"),order: 0, keyId: localKeyId),
                                      .init(entry:  Entry(id: "id1",
                              name: "Test2",
                              uri: "otpauth://totp/SimpleLogin:john.doe%40example.com?secret=CKTQQJVWT5IXTGD&amp;issuer=SimpleLogin",
                              period: 30,
                              issuer: "SimpleLogin",
                              secret: "CKTQQJVWT5IXTGD",
                              type: .totp,
                                                          note: "Note"), order: 1, keyId: localKeyId),
                                      .init(entry: Entry(id: "id2",
                              name: "Test3",
                              uri: "otpauth://totp/SimpleLogin:john.doe%40example.com?secret=CKTQQJVWT5IXTGD&amp;issuer=SimpleLogin",
                              period: 30,
                              issuer: "SimpleLogin",
                              secret: "CKTQQJVWT5IXTGD",
                              type: .totp,
                                                         note: "Note"),order: 2, keyId: localKeyId),
                                             OrderedEntry(entry: Entry(id: "id0",
                                                                       name: "Test",
                                                                       uri: "otpauth://totp/SimpleLogin:john.doe%40example.com?secret=CKTQQJVWT5IXTGD&amp;issuer=SimpleLogin",
                                                                       period: 40,
                                                                       issuer: "SimpleLogin",
                                                                       secret: "CKTQQJVWT5IXTGD",
                                                                       type: .totp,
                                                                       note: "new note"), order: 3, keyId: localKeyId)
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
}

extension OrderedEntry {
    init(entry: Entry, order: Int, keyId: String) {
        self.init(entry: entry, keyId: keyId, remoteId: nil, order: order, modifiedTime: Date.now.timeIntervalSince1970, revision: 1, contentFormatVersion: 1)
    }
}
