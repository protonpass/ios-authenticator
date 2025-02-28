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
    let sut: ImportingService

    init() {
        sut = ImportingService()
    }
    
    @Test("Test import from decrypted 2fas")
    func importEntriesFrom2fas() throws {
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
        let result = try sut.importEntries(from: .twofas(contents: stringData, password: nil))

        // Assert
        #expect(result.entries.count == 2)
        #expect(result.errors.count == 0)
        #expect(result.entries.first?.name == "mylabeldefault")
        #expect(result.entries.last?.name == "")
    }
    
    
    @Test("Test import from encrypted 2fas")
    func importEncryptedEntriesFrom2fas() async throws {
       let stringData = """
  {
    "services": [],
    "groups": [],
    "updatedAt": 1738060518498,
    "schemaVersion": 4,
    "appVersionCode": 5000029,
    "appVersionName": "5.4.8",
    "appOrigin": "android",
    "servicesEncrypted": "vHaJlrtehS0Si1YIFI+DsdZMirSjqi3P+KtY+sHZCjVFg2YdJTftO6iCdQFLSYP9r7rNG8DBWFx4FUBMm9sMGdEB8D+GZ6RikXDGhdm4jUUb0Nl3fVQJzivmeHPe8e73j49qqsqRicTH1IilMpRbgN33DaxoNYI/ziJNtCaYlKS+Y7XVMsaZuPR9cQSmPZhLUc68uU3KMYNHEqQd8Om/+LWOvKb1V4rq4QPWHZyh+JzBGQ3QbkhlQf9y+VND0bwM5cTKzhs/jnudpAiQU8acOJSNq5OyA2vaschYJs3kvg41i7k/dYku/TeoGpSwbnomE6JIHkSX08OrV4RxibHt1+DEyruU3HaCMSdJ3FtfY8SsU8tzgTMbxqyQwkDJ6RdXiKtLgGsy7PSwo5JCDn5+akALpuI0UYlbwgP1B0UKfR/kc11r/sfzp9+jISzU3FPhkx205aKn03g3VcTNFBdIakl3sqWDDjKJJ1uprg2AsvVNk7AJJIUPiOVQ2b51JJmMCmq1PdJrK1DxJz3ZkXkt26C/Z36gdzMJYkHnZWpQh2umbqhd7PtTWnUSBQiIF9SVA0kQx7hjax5hCssrqBARWWskvr/rBTgbeWrHMhjknS084gLK/DFsvKSrNplKAbQNaLV40OV0EYOhD8G1Ikgk/bivlb0Yp28I8oQFyIetNZnYWHNUAYDjZpFHjK9DKhEuBUIi8yZhhdG0Fgx3K8TUzDSjJ+TujI9PTqL7mBFedDv1SWll9b/9FYff8O8mF2+B6cnRd7pLFHMcI4grB8eDhIO2nZuzObnAw/niJxvbbmFkPLHQnUHsQs7OroOox0hqj7VFgalEHrVAi1DbOgRnAou38n+APEQy3PJiHTPZk54gZ7jWrEkk+K/w3GbXvyzCnACTOSmDmOyaIdv5FA1gmm5OExwN9ltrm11yh7NWsofQDI+QGrrB7V4aksqwS0qz8il/1vhSH4P6/EhuC92h0ky2zud5NdOfBsJ8:JFpdtsTBX31A+tYxmLikSmPM/amVh7rOZL0gTu2iUBzO12cBBMIm/t+VCSGacSMS4lluwQjlSWFE4lJ7sCmZxTGxDh1GcQd31speMzWxWPu6FSnt4kD1N16NX9yqKd3hkxbKZ0jyK04IW+uNBItMoH2GvmZF2p9NZ3Xs9oRljXoffrq8fLD7Are/J+N2PGekbT/XY9CEKgBWfi04xFfMKJ8lZy8DEmR013F8PbOTEEmujnXznoiltfWKy1z8x25IRL30Ak86EJgtmQ6qRCY74iU59T/MW5EBKBWStqdYlOBtnHzZ8KSGEkpy9TK2MiSQeSRX9oLKpzAqUPKLu4G4Xg==:pYsYDrS0dv9uWJPU",
    "reference": "vwIh3XpwPDbXX4aGXV9T6k3WFVbPlwd9/DYTQEEabLWdsGAOfuNJrt5gJbXPjAP88rF/g7X6hYm+Ib89dveDRhmixF6N4KdjOswePkgi2nUZCFH5cwkGh7UmdbrbIBw/60EDmPvYO+koJYQSZVXYIBsBnYCEVc6/JoxcOcWi9YcYVWAA02+bChDqQ6GrNW78O4eh+TRz7ZxF2VuN23I2sA4Z2ccIlPTK2LhZchOCFO2UVFgvUlZzAB6vv78Kf4cCxWrlYh2NmaEGNRfY6zB7G/L2WYRL3pkXe4HgTYltjDJlQjfV6YP0e8cDvAbY+kFtfgE2fyjy0o/SrDaTJ5GaTAuJT1/TfURPPepntF2vM9M=:JFpdtsTBX31A+tYxmLikSmPM/amVh7rOZL0gTu2iUBzO12cBBMIm/t+VCSGacSMS4lluwQjlSWFE4lJ7sCmZxTGxDh1GcQd31speMzWxWPu6FSnt4kD1N16NX9yqKd3hkxbKZ0jyK04IW+uNBItMoH2GvmZF2p9NZ3Xs9oRljXoffrq8fLD7Are/J+N2PGekbT/XY9CEKgBWfi04xFfMKJ8lZy8DEmR013F8PbOTEEmujnXznoiltfWKy1z8x25IRL30Ak86EJgtmQ6qRCY74iU59T/MW5EBKBWStqdYlOBtnHzZ8KSGEkpy9TK2MiSQeSRX9oLKpzAqUPKLu4G4Xg==:DJtLQp1wy4PbZufx"
  }
"""
        // Act
        let result = try sut.importEntries(from: .twofas(contents: stringData, password: "test"))

        // Assert
        #expect(result.entries.count == 2)
        #expect(result.errors.count == 0)
        #expect(result.entries.first?.name == "mylabeldefault")
        #expect(result.entries.last?.name == "")
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
