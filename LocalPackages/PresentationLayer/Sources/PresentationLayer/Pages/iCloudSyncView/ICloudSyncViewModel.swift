//
//
// ICloudSyncViewModel.swift
// Proton Authenticator - Created on 20/05/2026.
// Copyright (c) 2026 Proton Technologies AG
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
//

import Combine
import CommonUtilities
import DataLayer
import FactoryKit
import Foundation
import LocalAuthentication
import Macro
import Models

@Observable
final class ICloudSyncViewModel {
    private(set) var iCloudSync = false

    @ObservationIgnored
    private var toggleICloudSyncTask: Task<Void, Never>?

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.settingsService) private var settingsService

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.localDataManager) private var localDataManager

    @ObservationIgnored
    @LazyInjected(\ToolsContainer.updatingSettings)
    private(set) var updatingSettings

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.alertService)
    private var alertService

    @ObservationIgnored
    @LazyInjected(\ToolsContainer.logManager)
    private(set) var logManager

    @ObservationIgnored
    @LazyInjected(\UseCaseContainer.authenticateBiometrically)
    private var authenticateBiometrically

    init() {
        setUp()
    }

    func toggleICloudSyncBackup() {
        guard toggleICloudSyncTask == nil else { return }
        toggleICloudSyncTask = Task { [weak self] in
            guard let self else { return }
            defer { toggleICloudSyncTask = nil }
            var bioAuthenticated = false
            await authenticateAndPerform {
                settingsService.toggleICloudSync(!iCloudSync)
                iCloudSync.toggle()
                if iCloudSync {
                    settingsService.setICloudDisablePromptDismissed(true)
                }
                bioAuthenticated = true
            }
            if bioAuthenticated {
                await localDataManager.refreshLocalStorage()
            }
        }
    }
}

private extension ICloudSyncViewModel {
    func setUp() {
        iCloudSync = settingsService.iCloudSync
    }

    func authenticateAndPerform(_ block: () throws -> Void) async {
        defer { updatingSettings.send(false) }
        updatingSettings.send(true)
        let reason = #localized("Please authenticate", bundle: .module)
        do {
            if try await authenticateBiometrically(policy: AppConstants.laEnablingPolicy,
                                                   reason: reason) {
                try block()
            }
        } catch {
            handle(error)
        }
    }

    func handle(_ error: any Error) {
        logManager.log(.error, category: .ui, error.localizedDescription)
        if let laError = error as? LAError, laError.code == .userCancel { return }
        alertService.showError(error, mainDisplay: false, action: nil)
    }
}
