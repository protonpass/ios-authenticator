//
// LocalDataManager.swift
// Proton Authenticator - Created on 03/06/2025.
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
import SwiftData

public protocol LocalDataManagerProtocol: Sendable, Actor {
    var persistentStorage: any PersistenceServicing { get }

    func refreshLocalStorage() async
}

public actor LocalDataManager: LocalDataManagerProtocol {
    private let settingsService: any SettingsServicing

    public private(set) var persistentStorage: any PersistenceServicing

    @MainActor
    public init(settingsService: any SettingsServicing) {
        self.settingsService = settingsService
        persistentStorage = LocalDataManager
            .createPersistenceService(iCloudSyncEnabled: settingsService.iCloudBackUp)
    }

    public func refreshLocalStorage() async {
        let iCloudSyncEnabled = await settingsService.iCloudBackUp
        persistentStorage = LocalDataManager.createPersistenceService(iCloudSyncEnabled: iCloudSyncEnabled)
    }
}

private extension LocalDataManager {
    static func createPersistenceService(iCloudSyncEnabled: Bool) -> PersistenceService {
        let cloudKitDatabase: ModelConfiguration
            .CloudKitDatabase = iCloudSyncEnabled ? .private("iCloud.me.proton.authenticator") : .none
        do {
            let entryConfig = ModelConfiguration(schema: Schema([EncryptedEntryEntity.self]),
                                                 isStoredInMemoryOnly: false,
                                                 cloudKitDatabase: cloudKitDatabase)
            let localDataConfig = ModelConfiguration("localData",
                                                     schema: Schema([
                                                         LogEntryEntity.self,
                                                         EncryptedUserDataEntity.self
                                                     ]),
                                                     isStoredInMemoryOnly: false,
                                                     cloudKitDatabase: .none)
            return try PersistenceService(for: EncryptedEntryEntity.self,
                                          LogEntryEntity.self,
                                          EncryptedUserDataEntity.self,
                                          configurations: entryConfig,
                                          localDataConfig)
        } catch {
            fatalError("Should have persistence storage \(error)")
        }
    }
}
