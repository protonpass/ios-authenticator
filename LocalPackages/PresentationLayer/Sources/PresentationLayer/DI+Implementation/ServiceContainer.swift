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
import DomainProtocols
import Factory

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
        self { @MainActor in QAService(store: kSharedUserDefaults) }
    }

    var entryDataService: Factory<any EntryDataServiceProtocol> {
        self { @MainActor in EntryDataService(repository: RepositoryContainer.shared.entryRepository()) }
    }
}
