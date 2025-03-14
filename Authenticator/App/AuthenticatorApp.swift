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
    @State private var appSettings = ServiceContainer.shared.settingsService()
    @Injected(\ServiceContainer.deepLinkService) var deepLinkService
    @State private var alertService = resolve(\ServiceContainer.alertService)

    var body: some Scene {
        WindowGroup {
            EntriesView()
                .preferredColorScheme(appSettings.theme.preferredColorScheme)
                .onOpenURL { url in
                    Task {
                        try? await deepLinkService.handleDeeplinks(url)
                    }
                }
                .alert(alertService.alert?.configuration.title ?? "Unknown",
                       isPresented: Binding<Bool>(get: {
                                                      // Only show the alert if it's of type `.main`
                                                      if case .main = alertService.alert {
                                                          return alertService.showAlert
                                                      }
                                                      return false
                                                  },
                                                  set: { newValue in
                                                      alertService.showAlert = newValue
                                                  }),
                       presenting: alertService.alert,
                       actions: { display in
                           display.buildActions
                       },
                       message: { display in
                           Text(verbatim: display.configuration.message ?? "")
                       })
        }
        #if os(macOS)
        .windowResizability(.contentMinSize)
        #endif
    }
}
