//  
// ImportingServicesTests.swift
// Proton Authenticator - Created on 27/02/2025.
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

import Testing
import Models
@testable import DataLayer

struct ImportingServiceTests {
    let importingService: ImportingService

    init() {
        self.importingService = ImportingService()
    }
    
    @Test("Test import from decrypted 2fas")
    func testImportEntriesFrom2fas() throws {
       let stringData = """
        {
          "services": [
            {
              "name": "myissuer",
              "secret": "MYSECRET",
              "updatedAt": 1738059994570,
              "otp": {
                "label": "mylabeldefault",
                "account": "mylabeldefault",
                "issuer": "myissuer",
                "digits": 6,
                "period": 30,
                "algorithm": "SHA1",
                "tokenType": "TOTP",
                "source": "Link"
              },
              "order": {
                "position": 0
              },
              "icon": {
                "selected": "Label",
                "label": {
                  "text": "MY",
                  "backgroundColor": "Indigo"
                },
                "iconCollection": {
                  "id": "a5b3fb65-4ec5-43e6-8ec1-49e24ca9e7ad"
                }
              }
            },
            {
              "name": "Steam",
              "secret": "STEAMKEY",
              "updatedAt": 1738059994575,
              "serviceTypeID": "d241edff-480f-4201-840a-5a1c1d1323c2",
              "otp": {
                "issuer": "Steam",
                "digits": 5,
                "period": 30,
                "algorithm": "SHA1",
                "tokenType": "STEAM",
                "source": "Link"
              },
              "order": {
                "position": 1
              },
              "icon": {
                "selected": "IconCollection",
                "iconCollection": {
                  "id": "d5fd5765-bc30-407a-923f-e1dfd5cec49f"
                }
              }
            }
          ],
          "groups": [],
          "updatedAt": 1738060509269,
          "schemaVersion": 4,
          "appVersionCode": 5000029,
          "appVersionName": "5.4.8",
          "appOrigin": "android"
        }
"""
        // Act
        let result = try importingService.importEntries(from: .twofas(contents: stringData, password: nil))

        // Assert
        #expect(result.entries.count == 2)
        #expect(result.errors.count == 0)
        #expect(result.entries.first?.name == "myissuer")
        #expect(result.entries.last?.name == "Steam")
    }

//    @Test
//    func testImportEntriesFrom2fasWithEmptyContent() throws {
//        // Arrange
//        importingService = ImportingService(importer: mockImporter)
//
//        // Act & Assert
//        try #expect(throws: ImportingServiceError.contentIsEmpty) {
//            try importingService.importEntries(from: .twofas(contents: "", password: "password"))
//        }
//    }
//
//    @Test
//    func testImportEntriesFromAegis() throws {
//        // Arrange
//        mockImporter.importFromAegisJsonResult = .success(AuthenticatorImportResult())
//        importingService = ImportingService(importer: mockImporter)
//
//        // Act
//        let result = try importingService.importEntries(from: .aegis(contents: "validContent", password: "password"))
//
//        // Assert
//        #expect(result == ImportResult())
//    }
//
//    @Test
//    func testImportEntriesFromAegisWithEmptyContent() throws {
//        // Arrange
//        importingService = ImportingService(importer: mockImporter)
//
//        // Act & Assert
//        try #expect(throws: ImportingServiceError.contentIsEmpty) {
//            try importingService.importEntries(from: .aegis(contents: "", password: "password"))
//        }
//    }
//
//    @Test
//    func testImportEntriesFromBitwardenJson() throws {
//        // Arrange
//        mockImporter.importFromBitwardenJsonResult = .success(AuthenticatorImportResult())
//        importingService = ImportingService(importer: mockImporter)
//
//        // Act
//        let result = try importingService.importEntries(from: .bitwarden(contents: "validJsonContent"))
//
//        // Assert
//        #expect(result == ImportResult())
//    }
//
//    @Test
//    func testImportEntriesFromBitwardenCsv() throws {
//        // Arrange
//        mockImporter.importFromBitwardenCsvResult = .success(AuthenticatorImportResult())
//        importingService = ImportingService(importer: mockImporter)
//
//        // Act
//        let result = try importingService.importEntries(from: .bitwarden(contents: "validCsvContent"))
//
//        // Assert
//        #expect(result == ImportResult())
//    }
//
//    @Test
//    func testImportEntriesFromBitwardenWithInvalidFormat() throws {
//        // Arrange
//        importingService = ImportingService(importer: mockImporter)
//
//        // Act & Assert
//        try #expect(throws: ImportingServiceError.wrongFormat) {
//            try importingService.importEntries(from: .bitwarden(contents: "invalidContent"))
//        }
//    }
//
//    // Add more tests for other destinations (Ente, GoogleQr, Lastpass, ProtonAuthenticator) following the same pattern.
}
