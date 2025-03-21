//
// ToolsContainer.swift
// Proton Authenticator - Created on 04/03/2025.
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
import LocalAuthentication
import SimplyPersist
import SwiftData

// swiftlint:disable line_length
final class ToolsContainer: SharedContainer, AutoRegistering, Sendable {
    static let shared = ToolsContainer()
    let manager = ContainerManager()

    func autoRegister() {
        manager.defaultScope = .singleton
    }
}

extension ToolsContainer {
    var persistenceService: Factory<any PersistenceServicing> {
        self {
            do {
                let schema = Schema([EncryptedEntryEntity.self])
                return try PersistenceService(with: ModelConfiguration(schema: schema,
                                                                       isStoredInMemoryOnly: false,
                                                                       cloudKitDatabase: .private("iCloud.me.proton.authenticator")))
            } catch {
                fatalError("Should have persistence storage \(error)")
            }
        }
    }

    var logService: Factory<any LoggerProtocol> {
        self {
            LogService()
        }
    }

    var encryptionKeyStoreService: Factory<any EncryptionKeyStoring> {
        self {
            EncryptionKeyStoreService(logger: self.logService())
        }
    }

    var laContext: Factory<LAContext> {
        self { LAContext() }
    }

    /// Used when users enable biometric authentication. Always fallback to device passcode in this case.
    var laEnablingPolicy: Factory<LAPolicy> {
        self { .deviceOwnerAuthentication }
    }
}

// swiftlint:enable line_length
