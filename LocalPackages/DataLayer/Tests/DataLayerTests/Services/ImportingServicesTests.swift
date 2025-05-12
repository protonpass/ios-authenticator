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
import DataLayer

@Suite(.tags(.service))
struct ImportingServiceTests {
    let sut: ImportingService

    init() {
        sut = ImportingService(logger: MockLogger())
    }
    
    @Test("Test import from decrypted 2fas")
    func importEntriesFrom2fas() throws {
        // Act
        let result = try sut.importEntries(from: .twofas(contents: MockImporterData.decrypted2fas, password: nil))

        // Assert
        #expect(result.entries.count == 2)
        #expect(result.errors.count == 0)
        #expect(result.entries.first?.name == "mylabeldefault")
        #expect(result.entries.last?.name == "Steam")
    }
    
    @Test("Test import from encrypted 2fas")
    func importEncryptedEntriesFrom2fas() async throws {
        // Act
        let result = try sut.importEntries(from: .twofas(contents: MockImporterData.encrypted2fas, password: "test"))

        // Assert
        #expect(result.entries.count == 2)
        #expect(result.errors.count == 0)
        #expect(result.entries.first?.name == "mylabeldefault")
        #expect(result.entries.last?.name == "Steam")
    }
    
    @Test("Test fail import from entries from 2fas")
    func failimportEntriesFrom2fas() async throws {

        #expect(throws: AuthenticatorImportException.BadPassword(message: "BadPassword")) {
            try sut.importEntries(from: .twofas(contents: MockImporterData.encrypted2fas, password: "wrong"))
        }

        #expect(throws: AuthenticatorImportException.MissingPassword(message: "MissingPassword")) {
            try sut.importEntries(from: .twofas(contents: MockImporterData.encrypted2fas, password: nil))
        }
        
        #expect(throws: AuthError.importing(.contentIsEmpty)) {
            try sut.importEntries(from: .twofas(contents: "", password: nil))
        }
    }
    @Test("Test import json from Aegis")
    func importJsonEntriesFromAegis() throws {
        // Act
        let result = try sut.importEntries(from: .aegis(contents: .json(MockImporterData.decryptedAegisJson), password: nil))

        // Assert
        #expect(result.entries.count == 3)
        #expect(result.errors.count == 0)
        #expect(result.entries.first?.name == "mylabel815256")
        #expect(result.entries.last?.name == "Steam")
    }
    
    @Test("Test import txt from Aegis")
    func importTxtEntriesFromAegis() throws {
        // Act
        let result = try sut.importEntries(from: .aegis(contents: .txt(MockImporterData.txtAegis), password: nil))

        // Assert
        #expect(result.entries.count == 3)
        #expect(result.errors.count == 0)
        #expect(result.entries.first?.name == "mylabel815256")
        #expect(result.entries.last?.name == "")
    }
    
    @Test("Test import encrypted json from Aegis")
    func importEncryptedJsonEntriesFromAegis() throws {

        // Act
        let result = try sut.importEntries(from: .aegis(contents: .json(MockImporterData.encryptedAegisJson), password: "test"))

        // Assert
        #expect(result.entries.count == 3)
        #expect(result.errors.count == 0)
        #expect(result.entries.first?.name == "mylabel815256")
        #expect(result.entries.last?.name == "Steam")
    }
    
    @Test("Test fail import from encrypted aegis entries")
    func failImportEntriesFromAegis() async throws {

        #expect(throws: AuthenticatorImportException.BadPassword(message: "BadPassword")) {
            try sut.importEntries(from: .aegis(contents: .json(MockImporterData.encryptedAegisJson), password: "wrong"))
        }

        //Should be commented out when we have a new version of the rust lib
//        #expect(throws: AuthenticatorImportException.MissingPassword(message: "MissingPassword")) {
//            try sut.importEntries(from: .aegis(contents: MockImporterData.encryptedAegisJson, password: nil))
//        }
//        
        #expect(throws: AuthError.importing(.contentIsEmpty)) {
            try sut.importEntries(from: .aegis(contents: .txt(""), password: nil))
        }
    }
    
    @Test("Test import json from bitwarden")
    func importJsonEntriesFromBitwarden() throws {
        // Act
        let result = try sut.importEntries(from: .bitwarden(contents: .json(MockImporterData.bitwardenJson)))

        // Assert
        #expect(result.entries.count == 4)
        #expect(result.errors.count == 0)
        #expect(result.entries.first?.name == "LABEL_256_8_15")
        #expect(result.entries.last?.name == "Seven digit username")
    }
    
    @Test("Test import csv from bitwarden")
    func importCsvEntriesFromBitwarden() throws {
        // Act
        let result = try sut.importEntries(from: .bitwarden(contents: .csv( MockImporterData.bitwardenCsv)))

        // Assert
        #expect(result.entries.count == 4)
        #expect(result.errors.count == 0)
        #expect(result.entries.first?.name == "LABEL_256_8_15")
        #expect(result.entries.last?.name == "Seven digit username")
    }
    
    @Test("Test import wrong csv from bitwarden")
    func failImportCsvEntriesFromBitwarden() throws {
        #expect(throws: AuthenticatorImportException.BadContent(message: "BadContent")) {
            try sut.importEntries(from: .bitwarden(contents: .csv("plop, plop\nplop")))
        }
    }
    
    @Test("Test import txt from ente")
    func importTxtEntriesFromEnte() throws {
        // Act
        let result = try sut.importEntries(from: .ente(contents: MockImporterData.enteTxt))

        // Assert
        #expect(result.entries.count == 2)
        #expect(result.errors.count == 0)
        #expect(result.entries.first?.name == "MyLabel256_8_15")
        #expect(result.entries.last?.name == "MyLabelDefault")
    }
    
    @Test("Test import json from lastpass")
    func importJsonEntriesFromLastpass() throws {
        // Act
        let result = try sut.importEntries(from: .lastpass(contents: .json(MockImporterData.lastpassJson)))

        // Assert
        #expect(result.entries.count == 3)
        #expect(result.errors.count == 0)
        #expect(result.entries.first?.name == "account name default")
        #expect(result.entries.last?.name == "sha512 name")
    }
}


enum MockImporterData {
    static let decrypted2fas: String = """
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
    static let encrypted2fas: String = """
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
    
    static let decryptedAegisJson: String = """
{
    "version": 1,
    "header": {
        "slots": null,
        "params": null
    },
    "db": {
        "version": 3,
        "entries": [
            {
                "type": "totp",
                "uuid": "641e6db3-296a-49ad-ab75-9f4069ba0e53",
                "name": "mylabel815256",
                "issuer": "myissuer",
                "note": "",
                "favorite": false,
                "icon": null,
                "info": {
                    "secret": "MYSECRET",
                    "algo": "SHA256",
                    "digits": 8,
                    "period": 15
                },
                "groups": []
            },
            {
                "type": "totp",
                "uuid": "c3d22748-1cd9-4a3e-a655-23a872e3eee2",
                "name": "mylabeldefault",
                "issuer": "myissuer",
                "note": "",
                "favorite": false,
                "icon": null,
                "info": {
                    "secret": "MYSECRET",
                    "algo": "SHA1",
                    "digits": 6,
                    "period": 30
                },
                "groups": []
            },
            {
                "type": "steam",
                "uuid": "776e9abf-a0b5-4d60-98ae-6e06664e5b1e",
                "name": "Steam",
                "issuer": "Steam",
                "note": "",
                "favorite": false,
                "icon": null,
                "info": {
                    "secret": "STEAMKEY",
                    "algo": "SHA1",
                    "digits": 5,
                    "period": 30
                },
                "groups": []
            }
        ],
        "groups": [],
        "icons_optimized": true
    }
}
"""
    
    static let encryptedAegisJson = """
{
    "version": 1,
    "header": {
        "slots": [
            {
                "type": 1,
                "uuid": "12dc9537-e949-4a74-81ed-9a9d1dd627a1",
                "key": "4b12b03b214c6a50fbdecf29463f43e3b68f9d14536ceba418f65f6d03a25e31",
                "key_params": {
                    "nonce": "e5c83664c38a64175b021edb",
                    "tag": "847f4dd400614f21cd81c9b9793f89ea"
                },
                "n": 32768,
                "r": 8,
                "p": 1,
                "salt": "133b37b6b6ce7e8bbd7980e520a94bf9ba041ac5dfbf8bb6df07728c5f57f0d7",
                "repaired": true,
                "is_backup": false
            }
        ],
        "params": {
            "nonce": "795324d644a585e5ff6d11a1",
            "tag": "8097bfbb663b97bbaca30912df65cbe4"
        }
    },
      "db": \(#"""
        "IvZKCAJ69YeNwkMtNEDXP2jfsTdLkYz3QU+wiXrcOyXTKumGySOlm987eQNnNVxpXcKkRNJwOFVZOk\/8dYCDYYYjmFwpWwlmBwJ8oa1GyXw+hhY0V6x22a\/yHrEnfsibJxnI27w8Rl2ThjRi68+ts43jpoR72VVCDb559m5Xb5cOWdTX2hE0Doj73OanKV2hlXY6kE2CWR41oA4l17MRiv\/iCBvHszMd2Xkt7q8gjG17\/zvvuM4Vrn2zDFnE\/OPUSm3NBx0fOk+PjDvfHLPFqPSbRh6+ozj8NTFZrsi8QNPjKSvhjjnH56DOoSOm7bZ\/9BsCHd+n6sZegtC50atOo5Ar5Q3x9Ssb3jwXtkYGU1uxYnbUrHz+eBlCuZrt1dVoy3Y4XWWN7ti2F0TwMPWECqwytxHDqIAFFWsQUDoUNMDFdJX7n0U7IlRfCm5DUGyo2UlSSViIKlDTSXGFuzvz5Kag4fDVYi2oxvCef4LiS5our4+48kcj8ZomW\/dt5F5HtnlydxhiLlrKeOfl9jKPuTSp2Z2vnAPjBh9dt9gElQxEQHUfh6XjAZIV8sAV0kbp8O5DtHidi9iB1JgsJ+YgX6ii9XIqWBiEOxf0iUUZZmFstFptcfCu2gbvRaXxNHp378B5PyAmXThYVEjOAL\/Nr8Kx3UQrg2Eu+YTT5hzCNoEXLnzoSRPWzj77OilWRLWL4Bc\/46F1OE+wJUWlx+bVov80G5mzSE7TSRl5xGZTXwzQ7m+A2m6sTByhi6U2DxX1pyuqOVzom5GIXvxW7TEwUDp5bxAzP\/Y\/MV1Lor+HhDoVdTScuwXeFIadRJBzwkPh+d++UYajomgEsoOpSF3iak54vM\/V54mCF8Lk4OE5vh7LPyJTls4fECGbpR0WSX8ummkbeNqZ6FVbuh+BvMN+U4An4+22HxGGgaLAIfqsxZnvOnis9lQa54zFd9i0XhiBylfC33hcmRbPBZAiApvjkrnvwA\/fnH3XGz\/zcCxbdjmQFGAwXdRbJhSKPjsEQB0F7LlAbjeHmTDOXUYgbhEyFqo3Qn0EIQr4jn9wjyyJz7oll0iA+wyugT\/\/o1I33R+wYL5xYPMqueriQ1U0Zifrf7vyGrF6LBDsoy+0f2qVDZo1NpEJntWcmNBJ1FciO9+xvuJnfOXBTEflbK5439qBPzn6Zr5bWaUopqwUChzSqrEQjIRzHsGXsr5FxXkMRlQKm\/w1B+juywe\/LlbVzots2XPPPq\/aW90Rl149GrXL5H6qDKISEbwCXreEp\/Hw0MvYLux29piMo+NBy6SrY3WoSBAvKeqFaOdtO+Ci5oU6ri\/QhjtHqABgybudZItcjHK1iPDI+d5TZtiIjHoWyLv1UTdNxDBYNXTa80oS0aWYDJtF+eIt6Fzr\/vzfQQ1p5kD8idAAGFX8buP0zo9hQClHUDFvEDyEetL4KujAOz3YBIfAlyocBozusdFwbAf7uGC6uQrWWiDVeBf3OAxmjHm9Vp9QYFjTAT8wwZKsjNKxPswTPKjCrcQMOeuc+6VjM6TAv4vHdUsTOBt0FCkaFREpsMSnep3WiKdcS7aXX91YuM8CWm\/\/mc1oGzMHHt9jNGC1le4M\/QiPJRSL4fpcbhHCoiFuuj9PhgG6fs41dt6LMuaqfUJoRkjraCPIKWbcYjMzbwp3B1YkPdjJ681JNCw4Hx63mFl7Uc9hoiyY3GRHolVccsJL0SivUtYEsYnsLomdTBVcQ1KhHpDAYpHuWNw57RY25XnewLMrkNHe\/xMKkEy6qbvq+Y2izALgD+VUvN\/s9BFpLt3w9iCz9+DaJT4dTkGvI19FclXzCYxGWobU2WgFNkcGeCI\/ljhuVcg0m17q5H24r4fpeD0uqWoGmeYV37JWefxxJBhnfDrZwaWIc0c5OU4EohW8xqob9JE="
        """#)
}
"""
    
   static let txtAegis = """
otpauth://totp/myissuer%3Amylabel815256?period=15&digits=8&algorithm=SHA256&secret=MYSECRET&issuer=myissuer
otpauth://totp/myissuer%3Amylabeldefault?period=30&digits=6&algorithm=SHA1&secret=MYSECRET&issuer=myissuer
otpauth://steam/Steam%3ASteam?period=30&digits=5&algorithm=SHA1&secret=STEAMKEY&issuer=Steam
"""
    
    static let bitwardenJson = """
{
  "encrypted": false,
  "items": [
    {
      "id": "37bf650d-2154-4d92-9547-d96b75a5317e",
      "name": "ISSUER",
      "folderId": null,
      "organizationId": null,
      "collectionIds": null,
      "notes": null,
      "type": 1,
      "login": {
        "totp": "otpauth://totp/ISSUER%3ALABEL_256_8_15?secret=SECRETDATA&algorithm=SHA256&digits=8&period=15&issuer=ISSUER"
      },
      "favorite": false
    },
    {
      "id": "847dd7e4-22f5-4206-babb-4769539ec8ff",
      "name": "ISSUER_DEFAULT",
      "folderId": null,
      "organizationId": null,
      "collectionIds": null,
      "notes": null,
      "type": 1,
      "login": {
        "totp": "otpauth://totp/ISSUER_DEFAULT%3ALABEL_DEFAULT?secret=SOMESECRET&algorithm=SHA1&digits=6&period=30&issuer=ISSUER_DEFAULT"
      },
      "favorite": false
    },
    {
      "id": "b1315dd9-28f8-4fd2-afa4-37aed632c90e",
      "name": "SteamName",
      "folderId": null,
      "organizationId": null,
      "collectionIds": null,
      "notes": null,
      "type": 1,
      "login": {
        "totp": "steam://STEAMKEY"
      },
      "favorite": false
    },
    {
      "id": "72bb3758-174a-40c3-a9ea-c82cae9f5c22",
      "name": "SevenDigits",
      "folderId": null,
      "organizationId": null,
      "collectionIds": null,
      "notes": null,
      "type": 1,
      "login": {
        "totp": "otpauth://totp/SevenDigits%3ASeven%20digit%20username?secret=SEVENDIGITSECRET&algorithm=SHA1&digits=7&period=30&issuer=SevenDigits"
      },
      "favorite": false
    }
  ]
}
"""

    static let bitwardenCsv = """
folder,favorite,type,name,login_uri,login_totp
,,1,ISSUER,,otpauth://totp/ISSUER%3ALABEL_256_8_15?secret=SECRETDATA&algorithm=SHA256&digits=8&period=15&issuer=ISSUER,ISSUER,15,8
,,1,ISSUER_DEFAULT,,otpauth://totp/ISSUER_DEFAULT%3ALABEL_DEFAULT?secret=SOMESECRET&algorithm=SHA1&digits=6&period=30&issuer=ISSUER_DEFAULT,ISSUER_DEFAULT,30,6
,,1,SteamName,,steam://STEAMKEY,SteamName,30,6
,,1,SevenDigits,,otpauth://totp/SevenDigits%3ASeven%20digit%20username?secret=SEVENDIGITSECRET&algorithm=SHA1&digits=7&period=30&issuer=SevenDigits,SevenDigits,30,7
"""
    
    static let enteTxt = """
otpauth://totp/MyLabel256_8_15?secret=JVMVGRKDKJCVI%3D%3D%3D&issuer=MyIssuer&algorithm=SHA256&digits=8&period=15&codeDisplay=%7B%22pinned%22%3Afalse%2C%22trashed%22%3Afalse%2C%22lastUsedAt%22%3A0%2C%22tapCount%22%3A0%2C%22tags%22%3A%5B%5D%2C%22note%22%3A%22%22%2C%22position%22%3A0%2C%22iconSrc%22%3A%22%22%2C%22iconID%22%3A%22%22%7D
otpauth://totp/MyIssuer:MyLabelDefault?algorithm=sha1&digits=6&issuer=MyIssuer&period=30&secret=JVMVGRKDKJCVI%3D%3D%3D&codeDisplay=%7B%22pinned%22%3Afalse%2C%22trashed%22%3Afalse%2C%22lastUsedAt%22%3A0%2C%22tapCount%22%3A0%2C%22tags%22%3A%5B%5D%2C%22note%22%3A%22a+note%22%2C%22position%22%3A0%2C%22iconSrc%22%3A%22customIcon%22%2C%22iconID%22%3A%22proton%22%7D
"""
    
    static let lastpassJson = """
{
  "deviceId": "",
  "deviceSecret": "",
  "localDeviceId": "9dae8be5-83f1-4600-aefb-d50bafb071d1",
  "deviceName": "Google Pixel 6a",
  "version": 3,
  "accounts": [
    {
      "accountID": "c9ebcb42-6d85-4bf0-8bb4-414138c4660d",
      "lmiUserId": "",
      "issuerName": "issuer",
      "originalIssuerName": "kekdj",
      "userName": "account name default",
      "originalUserName": "didjsbbidjdbdusj",
      "pushNotification": false,
      "secret": "BDKSIEHWBDBBDBDZBZJ",
      "timeStep": 30,
      "digits": 6,
      "creationTimestamp": 1738075355820,
      "isFavorite": false,
      "algorithm": "SHA1",
      "folderData": {
        "folderId": 0,
        "position": 0
      }
    },
    {
      "accountID": "de8cb856-d13a-4b75-a44e-2347300d7c54",
      "lmiUserId": "",
      "issuerName": "other",
      "originalIssuerName": "other",
      "userName": "",
      "originalUserName": "sha256",
      "pushNotification": false,
      "secret": "JDJSKDKDKDKDKDKDK",
      "timeStep": 20,
      "digits": 8,
      "creationTimestamp": 1738083300789,
      "isFavorite": false,
      "algorithm": "SHA256",
      "folderData": {
        "folderId": 0,
        "position": 1
      }
    },
    {
      "accountID": "80cb78ed-46a2-4fca-bd2c-11523b1eb647",
      "lmiUserId": "",
      "issuerName": "",
      "originalIssuerName": "",
      "userName": "sha512 name",
      "originalUserName": "sha512 name",
      "pushNotification": false,
      "secret": "JDJDDJDJUEJEBDBFNF",
      "timeStep": 30,
      "digits": 6,
      "creationTimestamp": 1738083337090,
      "isFavorite": false,
      "algorithm": "SHA512",
      "folderData": {
        "folderId": 0,
        "position": 2
      }
    }
  ],
  "folders": [
    {
      "id": 1,
      "name": "Favorites",
      "isOpened": true
    },
    {
      "id": 0,
      "name": "Other accounts",
      "isOpened": true
    }
  ],
  "backupInfo": {
    "creationDate": "2025-01-28T16:55:54.040",
    "deviceOS": "android",
    "appVersion": "2.21.3"
  }
}
"""
}
