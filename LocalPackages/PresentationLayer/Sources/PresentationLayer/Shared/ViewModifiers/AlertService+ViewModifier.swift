//
// AlertService+ViewModifier.swift
// Proton Authenticator - Created on 17/03/2025.
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
import Foundation
import SwiftUI

struct AlertServiceModifier: ViewModifier {
    @State private var alertService = resolve(\ServiceContainer.alertService)
    let isMainDisplay: Bool

    func body(content: Content) -> some View {
        content
            .alert(alertService.alert.titleText,
                   isPresented: isMainDisplay ? $alertService.showMainAlert : $alertService.showSheetAlert,
                   presenting: alertService.alert,
                   actions: { display in
                       display.actions
                   },
                   message: { display in
                       if let message = display.message {
                           Text(message)
                       }
                   })
    }
}

public extension View {
    func mainAlertService() -> some View {
        modifier(AlertServiceModifier(isMainDisplay: true))
    }

    func sheetAlertService() -> some View {
        modifier(AlertServiceModifier(isMainDisplay: false))
    }
}

private extension AlertDisplay? {
    var titleText: Text {
        // swiftlint:disable:next discouraged_optional_self
        if let title = self?.title {
            Text(title, bundle: .module)
        } else {
            Text(verbatim: "")
        }
    }
}
