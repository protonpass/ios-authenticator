//
// UseCaseContainer.swift
// Proton Authenticator - Created on 19/02/2025.
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
import DomainLayer
import FactoryKit

public final class UseCaseContainer: SharedContainer, AutoRegistering {
    public static let shared = UseCaseContainer()
    public let manager = ContainerManager()

    public func autoRegister() {
        manager.defaultScope = .singleton
    }
}

private extension UseCaseContainer {
    var logger: any LoggerProtocol {
        ToolsContainer.shared.logManager()
    }

    var settingsService: any SettingsServicing {
        ServiceContainer.shared.settingsService()
    }
}

extension UseCaseContainer {
    var copyTextToClipboard: Factory<any CopyTextToClipboardUseCase> {
        self { CopyTextToClipboard() }
    }

    var parseImageQRCodeContent: Factory<any ParseImageQRCodeContentUseCase> {
        self { ParseImageQRCodeContent() }
    }

    var getBiometricStatus: Factory<any GetBiometricStatusUseCase> {
        self { GetBiometricStatus() }
    }

    var authenticateBiometrically: Factory<any AuthenticateBiometricallyUseCase> {
        self { AuthenticateBiometrically() }
    }

    var checkAskForReview: Factory<any CheckAskForReviewUseCase> {
        self { CheckAskForReview(settingsService: self.settingsService,
                                 entryDataService: ServiceContainer.shared.entryDataService(),
                                 logger: ToolsContainer.shared.logManager(),
                                 bundle: .main) }
    }

    var requestForReview: Factory<any RequestForReviewUseCase> {
        self { RequestForReview(reviewService: ServiceContainer.shared.reviewService(),
                                checkAskForReview: self.checkAskForReview()) }
    }
}

public extension UseCaseContainer {
    var updateAppAndRustVersion: Factory<any UpdateAppAndRustVersionUseCase> {
        self { UpdateAppAndRustVersion() }
    }

    var setUpFirstRun: Factory<any SetUpFirstRunUseCase> {
        self { @MainActor in SetUpFirstRun(settingsService: self.settingsService,
                                           authenticationService: ServiceContainer.shared.authenticationService(),
                                           logger: self.logger) }
    }

    var setUpSentry: Factory<any SetUpSentryUseCase> {
        self { SetUpSentry() }
    }

    var openAppSettings: Factory<any OpenAppSettingsUseCase> {
        self { OpenAppSettings() }
    }
}
