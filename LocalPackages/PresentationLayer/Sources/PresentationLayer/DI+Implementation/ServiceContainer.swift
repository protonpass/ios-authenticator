//
// ServiceContainer.swift
// Proton Authenticator - Created on 11/02/2025.
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

import CommonUtilities
import DataLayer
import Factory
import SwiftUI

public final class ServiceContainer: SharedContainer, AutoRegistering {
    public static let shared = ServiceContainer()
    public let manager = ContainerManager()

    public func autoRegister() {
        manager.defaultScope = .singleton
    }
}

private extension ServiceContainer {
    var logger: any LoggerProtocol {
        ToolsContainer.shared.logManager()
    }

    var entryRepository: any EntryRepositoryProtocol {
        RepositoryContainer.shared.entryRepository()
    }
}

public extension ServiceContainer {
    var settingsService: Factory<any SettingsServicing> {
        self { @MainActor in SettingsService(store: kSharedUserDefaults) }
    }

    var qaService: Factory<any QAServicing> {
        self { @MainActor in QAService(store: kSharedUserDefaults,
                                       repository: self.entryRepository) }
    }

    var entryDataService: Factory<any EntryDataServiceProtocol> {
        self { @MainActor in EntryDataService(repository: self.entryRepository,
                                              importService: self.importService(),
                                              totpGenerator: ToolsContainer.shared.totpGenerator(),
                                              totpIssuerMapper: ToolsContainer.shared.totpIssuerMapper(),
                                              logger: self.logger) }
    }

    var encryptionService: Factory<any EncryptionServicing> {
        self { EncryptionService(keychain: self.keychainService(),
                                 keysProvider: self.keyManager(),
                                 logger: self.logger) }
    }

    var keychainService: Factory<any KeychainServicing> {
        self { KeychainService(service: AppConstants.service,
                               accessGroup: AppConstants.keychainGroup,
                               logger: self.logger) }
    }

    var deepLinkService: Factory<any DeepLinkServicing> {
        self { DeepLinkService(service: self.entryDataService(),
                               alertService: self.alertService()) }
    }

    var alertService: Factory<any AlertServiceProtocol> {
        self { @MainActor in AlertService() }
    }

    var importService: Factory<any ImportingServicing> {
        self { ImportingService(logger: self.logger) }
    }

    var authenticationService: Factory<any AuthenticationServicing> {
        self { @MainActor in AuthenticationService(keychain: self.keychainService(),
                                                   logger: self.logger) }
    }

    var toastService: Factory<any ToastServiceProtocol> {
        self { @MainActor in ToastService() }
    }

    var userSessionManager: Factory<any UserSessionTooling> {
        self {
            UserSessionManager(configuration: APIManagerConfiguration(appVersion: ToolsContainer.shared
                                   .appVersion(),
                doh: AuthDoH(userDefaults: kSharedUserDefaults)),
            keychain: self.keychainService(),
            encryptionService: self.encryptionService(),
            userDataProvider: RepositoryContainer.shared.userDataSource(),
            logger: self.logger)
        }
    }

    var keyManager: Factory<any KeysProvider> {
        self {
            KeyManager(keychain: self.keychainService())
        }
    }
}
