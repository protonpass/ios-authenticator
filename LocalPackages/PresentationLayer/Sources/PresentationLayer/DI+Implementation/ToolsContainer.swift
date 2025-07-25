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

import AuthenticatorRustCore
import DataLayer
import FactoryKit
import LocalAuthentication
import SimplyPersist
import SwiftData

final class ToolsContainer: SharedContainer, AutoRegistering, Sendable {
    static let shared = ToolsContainer()
    let manager = ContainerManager()

    func autoRegister() {
        manager.defaultScope = .singleton
    }
}

extension ToolsContainer {
    var mobileTotpGenerator: Factory<any MobileTotpGeneratorProtocol> {
        self {
            do {
                return try MobileTotpGenerator(periodMs: UInt32(300),
                                               onlyOnCodeChange: true,
                                               currentTime: CurrentTimeProviderImpl())
            } catch {
                fatalError("Could not instanciate MobileTotpGenerator \(error)")
            }
        }
    }

    var totpGenerator: Factory<any TotpGeneratorProtocol> {
        self {
            TotpGenerator(rustTotpGenerator: self.mobileTotpGenerator())
        }
    }

    var logManager: Factory<any LoggerProtocol> {
        self {
            LogManager(localDataManager: ServiceContainer.shared.localDataManager())
        }
    }

    var laContext: Factory<LAContext> {
        self { LAContext() }
    }

    var totpIssuerMapper: Factory<any TOTPIssuerMapperServicing> {
        self { TOTPIssuerMapper() }
    }

    // periphery:ignore
    var reachabilityManager: Factory<any ReachabilityServicing> {
        self { ReachabilityManager() }
    }

    #if os(iOS)
    var hapticsManager: Factory<any HapticsServicing> {
        self { @MainActor in HapticsManager(settings: ServiceContainer.shared.settingsService()) }
    }
    #endif

    var appVersion: Factory<String> {
        self { "ios-authenticator@\(Bundle.main.fullAppVersionName)" }
    }

    #if os(iOS)
    var mobileLoginCoordinator: Factory<any MobileCoordinatorProtocol> {
        self {
            @MainActor in MobileLoginCoordinator(logger: self.logManager())
        }
        .shared
    }
    #endif

    var apiClient: Factory<any APIClientProtocol> {
        self { APIClient(manager: ServiceContainer.shared.userSessionManager(), logger: self.logManager()) }
    }
}
