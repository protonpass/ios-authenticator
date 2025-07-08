//  
// MockUserSessionTooling.swift
// Proton Authenticator - Created on 13/05/2025.
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

import DataLayer
import Combine
import ProtonCoreLogin
import ProtonCoreServices
import Models

public final class MockUserSessionTooling: @unchecked Sendable, UserSessionTooling {
    public var sessionWasInvalidated = PassthroughSubject<Bool, Never>()
    
    public var isAuthenticatedWithUserData = CurrentValueSubject<Bool, Never>(false)
    
    // MARK: - APIManagerProtocol

    public var isAuthenticated = CurrentValueSubject<Bool, Never>(false)
    public var apiService: APIService

    public var logoutCalled = false
    public var logoutShouldThrow: Bool = false

    public func logout() async throws {
        logoutCalled = true
        if logoutShouldThrow {
            throw MockError.stub
        }
    }

    // MARK: - UserInfoProviding

    public var userData: UserData?

    public var getUserDataResult: Result<UserData?, Error> = .success(nil)
    public private(set) var getUserDataCalled = false

    public func getUserData() async throws -> UserData? {
        getUserDataCalled = true
        return try getUserDataResult.get()
    }

    public var saveUserDataCalled = false
    public var saveUserDataValue: UserData?
    public var saveUserDataShouldThrow = false

    public func save(_ userData: UserData) async throws {
        saveUserDataCalled = true
        saveUserDataValue = userData
        if saveUserDataShouldThrow {
            throw MockError.stub
        }
    }

    public var encryptObjectResult: Result<String, Error> = .success("encrypted")
    public var encryptObjectCalled = false

    public func userKeyEncrypt<T: Codable>(object: T) throws -> String {
        encryptObjectCalled = true
        return try encryptObjectResult.get()
    }
    
    public var decryptObjectResult: Result<any Codable, Error> = .success("encrypted")
    public var decryptObjectCalled = false
    
    public func userKeyDecrypt<T: Codable>(remoteEncryptedKey: RemoteEncryptedKey) throws -> T {
        decryptObjectCalled = true
        return try decryptObjectResult.get() as! T
    }
    

    // If needed:
    // public var decryptObjectResult: Result<Any, Error> = ...
    // public func userKeyDecrypt<T: Codable>(encryptedData: Data) throws -> T { ... }

    // MARK: - Helpers

     enum MockError: Error {
        case stub
    }

     init(apiService: APIService = PMAPIService.dummyService()) {
        self.apiService = apiService
    }
    
    public func getRemoteEncryptionKeyLinkedToActiveUserKey(_ remoteKeys: [RemoteEncryptedKey]) throws -> RemoteEncryptedKey? {
        nil
    }
}

extension PMAPIService {
    static func dummyService() -> APIService {
        PMAPIService.createAPIServiceWithoutSession(environment: .black,
                                                    challengeParametersProvider: .empty)
    }
}
