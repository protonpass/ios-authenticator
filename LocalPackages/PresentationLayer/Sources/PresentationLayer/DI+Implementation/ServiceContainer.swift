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

    public var settingsService: Factory<any SettingsServicing> {
        self { @MainActor in SettingsService(store: kSharedUserDefaults) }
    }

    var qaService: Factory<any QAServicing> {
        self { @MainActor in QAService(store: kSharedUserDefaults,
                                       repository: RepositoryContainer.shared.entryRepository()) }
    }

    var entryDataService: Factory<any EntryDataServiceProtocol> {
        self { @MainActor in EntryDataService(repository: RepositoryContainer.shared.entryRepository(),
                                              importService: self.importService(),
                                              totpGenerator: ToolsContainer.shared.totpGenerator(),
                                              totpIssuerMapper: ToolsContainer.shared.totpIssuerMapper()) }
    }

    var encryptionService: Factory<any EncryptionServicing> {
        self { EncryptionService(keyStore: self.keychainService(), logger: ToolsContainer.shared.logManager()) }
    }

    var keychainService: Factory<any KeychainServicing> {
        self { KeychainService(service: AppConstants.service, accessGroup: AppConstants.keychainGroup) }
    }
}

public extension ServiceContainer {
    var deepLinkService: Factory<any DeepLinkServicing> {
        self { DeepLinkService(service: self.entryDataService(),
                               alertService: self.alertService()) }
    }

    var alertService: Factory<any AlertServiceProtocol> {
        self { @MainActor in AlertService() }
    }

    var importService: Factory<any ImportingServicing> {
        self { ImportingService() }
    }

    var authenticationService: Factory<any AuthenticationServicing> {
        self { @MainActor in AuthenticationService(keychain: self.keychainService()) }
    }

    var toastService: Factory<any ToastServiceProtocol> {
        self { @MainActor in ToastService() }
    }
}
