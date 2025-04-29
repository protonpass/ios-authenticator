//
// AlertConfiguration+Extensions.swift
// Proton Authenticator - Created on 28/04/2025.
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

#if os(iOS)
import DataLayer
import UIKit

extension AlertConfiguration {
    static func noCameraAccess(onEnterManually: @MainActor @escaping () -> Void) -> Self {
        let openSettingsAction = ActionConfig(title: "Open Settings", titleBundle: .module) {
            if let url = URL(string: UIApplication.openSettingsURLString),
               UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        }

        let enterManuallyAction = ActionConfig(title: "Enter manually",
                                               titleBundle: .module,
                                               action: onEnterManually)
        return .init(title: "Camera usage restricted",
                     titleBundle: .module,
                     message: .localized("Please enable camera access from Settings", .module),
                     actions: [openSettingsAction, enterManuallyAction, ActionConfig.cancel])
    }
}
#endif
