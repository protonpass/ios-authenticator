//  
// UserDataSourceTests.swift
// Proton Authenticator - Created on 07/05/2025.
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
import Foundation
import DataLayer
import SimplyPersist
import SwiftData
import ProtonCoreDataModel
import ProtonCoreLogin
import ProtonCoreNetworking

struct UserDataSourceTests {
    let sut: any UserDataProvider
    
    init() throws {
        let logger = MockLogger()
        let encryptionService = EncryptionService(keychain: MockKeychainService(),
                                                 keysProvider: MockKeyProvider(),
                                                 logger: MockLogger())
        let persistenceService = try PersistenceService(with: ModelConfiguration(for: EncryptedUserDataEntity.self,
                                                                                 isStoredInMemoryOnly: true))
        sut = UserDataSource(logger: logger, persistentStorage: persistenceService, encryptionService: encryptionService)

    }
    
    @Test("Test getUserData returns nil if no data exists")
    func noUserdata() async throws {
        let result = try await sut.getUserData()
        #expect(result == nil)
    }
    
    @Test("Test getUserData returns decrypted data if present")
    func getValidUserData() async throws {
        let userData = UserData.mock()
        try await sut.save(userData)
        let decryptedUserData = try #require(try await sut.getUserData())
        #expect(userData == decryptedUserData)
    }
    
    @Test("Test removing user by id")
    func removeUserById() async throws {
        let userData = UserData.mock()
        try await sut.save(userData)
        try #require(try await sut.getUserData())
        try await sut.remove(userData.user.ID)
        let result = try await sut.getUserData()
        #expect(result == nil)
    }
    
    @Test("Test removing user by data")
    func removeUserByData() async throws {
        let userData = UserData.mock()
        try await sut.save(userData)
        try #require(try await sut.getUserData())
        try await sut.remove(userData)
        let result = try await sut.getUserData()
        #expect(result == nil)
    }
    
    @Test("Test removing all user data")
    func removeAllUsers() async throws {
        let userData = UserData.mock()
        let userData2 = UserData.mock(id: "newId")

        try await sut.save(userData)
        try await sut.save(userData2)
        try #require(try await sut.getUserData())
        try await sut.removeAllUsers()
        let result = try await sut.getUserData()
        #expect(result == nil)
    }
    
    @Test("Test removing all user data")
    func updateUser() async throws {
        var userData = UserData.mock()

        try await sut.save(userData)
        let result = try #require(try await sut.getUserData())
        #expect(result.addresses.count == 1)

        try await sut.update(userData.cleanAddresses())
        let result2 = try #require(try await sut.getUserData())
        #expect(result2.addresses.isEmpty == true)
    }
}

private extension UserData {
    static func mock(id: String = "ID") -> UserData {
        let user = User(ID: id,
                        name: nil,
                        usedSpace: 0,
                        usedBaseSpace: 0,
                        usedDriveSpace: 0,
                        currency: "currency",
                        credit: 0,
                        maxSpace: 0,
                        maxBaseSpace: 0,
                        maxDriveSpace: 0,
                        maxUpload: 0,
                        role: 0,
                        private: 0,
                        subscribed: [],
                        services: 0,
                        delinquent: 0,
                        orgPrivateKey: nil,
                        email: nil,
                        displayName: nil,
                        keys: [])

        let address = Address(addressID: id,
                              domainID: nil,
                              email: "email",
                              send: .active,
                              receive: .active,
                              status: .enabled,
                              type: .protonDomain,
                              order: 0,
                              displayName: "name",
                              signature: "signature",
                              hasKeys: 0,
                              keys: [])
        return .init(credential: .preview,
                     user: user,
                     salts: [],
                     passphrases: [:],
                     addresses: [address],
                     scopes: [])
    }
    
    func cleanAddresses() -> UserData {
        UserData(credential: self.credential, user: self.user, salts: self.salts, passphrases: self.passphrases, addresses: [], scopes: self.scopes)
    }
}

extension AuthCredential {
    // periphery:ignore
    static var preview: AuthCredential {
        AuthCredential(sessionID: "sessionID",
                       accessToken: "accessToken",
                       refreshToken: "refreshToken",
                       userName: "userName",
                       userID: "userID",
                       privateKey: nil,
                       passwordKeySalt: nil)
    }
}

extension UserData: @retroactive Equatable {
    public static func == (lhs: UserData, rhs: UserData) -> Bool {
        return lhs.credential.description == rhs.credential.description
 &&
      lhs.user == rhs.user &&
     lhs.salts == rhs.salts &&
       lhs.passphrases == rhs.passphrases &&
       lhs.addresses == rhs.addresses &&
 lhs.scopes == rhs.scopes
    }
}
