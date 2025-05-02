//
// UserManager.swift
// Proton Authenticator - Created on 30/04/2025.
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

import Models
import SimplyPersist
import SwiftData

// public protocol UserManagerProtocol: Sendable, UserManagerProvider {
//    var currentActiveUser: CurrentValueSubject<UserData?, Never> { get }
//    var allUserAccounts: CurrentValueSubject<[UserData], Never> { get }
//
//    func setUp() async throws
//    func getActiveUserData() async throws -> UserData?
//    func upsertAndMarkAsActive(userData: UserData) async throws
//
//    /// When `onMemory` is `true`, we don't save the active user ID to the database
//    /// This is to let extensions dynamically switch between accounts when creating items
//    /// as we don't want extensions to affect the current active user.
//    func switchActiveUser(with userId: String, onMemory: Bool) async throws
//
//    func getAllUsers() async throws -> [UserData]
//    func remove(userId: String) async throws
//    func cleanAllUsers() async throws
//    nonisolated func setUserData(_ userData: UserData)
// }

public protocol UserManagerProtocol {}

public actor UserManager: UserManagerProtocol {
    private let persistentStorage: any PersistenceServicing
    private let logger: LoggerProtocol

//    public nonisolated let currentActiveUser = CurrentValueSubject<UserData?, Never>(nil)
//    public nonisolated let allUserAccounts: CurrentValueSubject<[UserData], Never> = .init([])
//
//    private var userProfiles = [UserProfile]()
//    private let userDataDatasource: any LocalUserDataDatasourceProtocol
//    private let logger: Logger
    private var didSetUp = false

    public init(persistentStorage: any PersistenceServicing,
                logger: LoggerProtocol) {
        self.persistentStorage = persistentStorage
        self.logger = logger
    }
}
