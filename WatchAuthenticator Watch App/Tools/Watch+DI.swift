//
// Watch+DI.swift
// Proton Authenticator - Created on 24/07/2025.
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
// along with Proton Pass. If not, see https://www.gnu.org/licenses/.

// periphery:ignore:all

import FactoryKit
import Foundation

final class WatchDIContainer: SharedContainer {
    static let shared = WatchDIContainer()
    let manager = ContainerManager()

    func autoRegister() {
        manager.defaultScope = .singleton
    }

    var keychainService: Factory<any KeychainServicing> {
        self { KeychainService() }
    }

    var localDataManager: Factory<any LocalDataManagerProtocol> {
        self { LocalDataManager() }
    }

    var watchToIOSCommunicationManager: Factory<any WatchCommunicationServiceProtocol> {
        self { WatchToIOSCommunicationManager() }
    }

    var encryptionService: Factory<any EncryptionServicing> {
        self { WatchEncryptionService(keychain: self.keychainService()) }
    }

    var entryRepository: Factory<any EntryRepositoryProtocol> {
        self { EntryRepository(localDataManager: self.localDataManager(),
                               encryptionService: self.encryptionService()) }
    }

    var countdownTimer: Factory<any CountdownTimerProtocol> {
        self { @MainActor in CountdownTimer.shared }
    }

    var dataService: Factory<any DataServiceProtocol> {
        self { @MainActor in DataService(repository: self.entryRepository(),
                                         communicationService: self.watchToIOSCommunicationManager()) }
    }
}
