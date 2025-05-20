//
// UserDataSource.swift
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

import Foundation
import ProtonCoreDataModel
import ProtonCoreLogin
@preconcurrency import ProtonCoreNetworking
import SimplyPersist

public protocol UserDataProvider {
    func getUserData() async throws -> UserData?
    func save(_ userData: UserData) async throws
    // periphery:ignore
    func remove(_ userId: String) async throws
    func removeAllUsers() async throws
    // periphery:ignore
    func update(_ userData: UserData) async throws
}

public extension UserDataProvider {
    func remove(_ userData: UserData) async throws {
        try await remove(userData.user.ID)
    }
}

public final class UserDataSource: UserDataProvider, LoggingImplemented {
    let logger: any LoggerProtocol
    private let encryptionService: any EncryptionServicing
    private let persistentStorage: any PersistenceServicing

    public init(logger: any LoggerProtocol,
                persistentStorage: any PersistenceServicing,
                encryptionService: any EncryptionServicing) {
        self.logger = logger
        self.persistentStorage = persistentStorage
        self.encryptionService = encryptionService
    }
}

public extension UserDataSource {
    func getUserData() async throws -> UserData? {
        log(.info, "Fetching user data")
        let encryptedUsersData: [EncryptedUserDataEntity] = try await persistentStorage.fetchAll()
        log(.info, "Got \(encryptedUsersData.count) user's data")
        guard let encryptedUserData = encryptedUsersData.first else {
            log(.info, "No user data found")
            return nil
        }
        do {
            let userData = try decrypt(encryptedData: encryptedUserData.encryptedData)
            log(.info, "Successfully decrypted user data")
            return userData
        } catch {
            log(.error, "Failed to decrypt user data: \(error.localizedDescription)")
            throw error
        }
    }

    func save(_ userData: UserData) async throws {
        log(.info, "Saving user data for ID: \(userData.user.ID)")
        do {
            let encryptedUserData = try encrypt(userData: userData)
            try await persistentStorage.save(data: encryptedUserData)
            log(.info, "Successfully saved encrypted user data")
        } catch {
            log(.error, "Failed to save user data: \(error.localizedDescription)")
            throw error
        }
    }

    // periphery:ignore
    func remove(_ userId: String) async throws {
        log(.info, "Removing user data by ID: \(userId)")
        do {
            let predicate = #Predicate<EncryptedUserDataEntity> { $0.id == userId }
            try await persistentStorage.delete(EncryptedUserDataEntity.self, predicate: predicate)
            log(.info, "Successfully removed user data with ID: \(userId)")
        } catch {
            log(.error, "Failed to remove user data with ID \(userId): \(error.localizedDescription)")
            throw error
        }
    }

    func removeAllUsers() async throws {
        log(.info, "Removing all user data")
        do {
            try await persistentStorage.deleteAll(dataTypes: [EncryptedUserDataEntity.self])
            log(.info, "Successfully removed all user data")
        } catch {
            log(.error, "Failed to remove all user data: \(error.localizedDescription)")
            throw error
        }
    }

    // periphery:ignore
    func update(_ userData: UserData) async throws {
        log(.info, "Updating user data for ID: \(userData.user.ID)")
        do {
            guard let entity = try await persistentStorage
                .fetchOne(predicate: #Predicate<EncryptedUserDataEntity> { $0.id == userData.user.ID }) else {
                log(.warning, "User data not found for update, ID: \(userData.user.ID)")
                return
            }
            let encryptedData = try encrypt(userData: userData)
            entity.updateEncryptedData(encryptedData.encryptedData)
            try await persistentStorage.save(data: entity)
            log(.info, "Successfully updated user data for ID: \(userData.user.ID)")
        } catch {
            log(.error, "Failed to update user data for ID \(userData.user.ID): \(error.localizedDescription)")
            throw error
        }
    }
}

private extension UserDataSource {
    func encrypt(userData: UserData) throws -> EncryptedUserDataEntity {
        let encryptedData = try encryptionService.symmetricEncrypt(object: userData)
        return EncryptedUserDataEntity(id: userData.user.ID, encryptedData: encryptedData)
    }

    func decrypt(encryptedData: Data) throws -> UserData {
        try encryptionService.symmetricDecrypt(encryptedData: encryptedData)
    }
}

// swiftlint:disable:next todo
// TODO: to be removed once proton core wis updated with the codable conformance
extension UserData: Codable {
    private enum CodingKeys: String, CodingKey {
        case credential
        case user
        case salts
        case passphrases
        case addresses
        case scopes
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(credential: container.decode(AuthCredential.self, forKey: .credential),
                      user: container.decode(User.self, forKey: .user),
                      salts: container.decode([KeySalt].self, forKey: .salts),
                      passphrases: container.decode([String: String].self, forKey: .passphrases),
                      addresses: container.decode([Address].self, forKey: .addresses),
                      scopes: container.decode([String].self, forKey: .scopes))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(credential, forKey: .credential)
        try container.encode(user, forKey: .user)
        try container.encode(salts, forKey: .salts)
        try container.encode(passphrases, forKey: .passphrases)
        try container.encode(addresses, forKey: .addresses)
        try container.encode(scopes, forKey: .scopes)
    }
}

extension UserData: @unchecked @retroactive Sendable {}
