//
// AuthenticatorApp.swift
// Proton Authenticator - Created on 12/02/2025.
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
import Factory
import Foundation
import PresentationLayer
import SwiftData
import SwiftUI

@main
struct AuthenticatorApp: App {
    @State private var viewModel = AuthenticatorAppViewModel()

    var body: some Scene {
        WindowGroup {
            EntriesView()
                .preferredColorScheme(viewModel.appSettings.theme.preferredColorScheme)
                .onOpenURL { url in
                    viewModel.handleDeepLink(url)
                }
                .alert(viewModel.alertService.alert?.title ?? "Unknown",
                       isPresented: $viewModel.alertService.showMainAlert,
                       presenting: viewModel.alertService.alert,
                       actions: { display in
                           display.buildActions
                       },
                       message: { display in
                           Text(verbatim: display.message ?? "")
                       })
        }
        #if os(macOS)
        .windowResizability(.contentMinSize)
        #endif
    }
}

@Observable @MainActor
private final class AuthenticatorAppViewModel {
    @ObservationIgnored
    @LazyInjected(\ServiceContainer.deepLinkService)
    private var deepLinkService

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.alertService)
    var alertService

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.settingsService)
    var appSettings

    init() {}

    func handleDeepLink(_ url: URL) {
        Task {
            do {
                try await deepLinkService.handleDeeplinks(url)
            } catch {
                alertService.showError(error)
            }
        }
    }
}
