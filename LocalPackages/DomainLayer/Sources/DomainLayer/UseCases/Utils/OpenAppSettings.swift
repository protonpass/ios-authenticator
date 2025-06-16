//
//
// OpenAppSettings.swift
// Proton Authenticator - Created on 16/06/2025.
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
//

import CommonUtilities
import Foundation
#if canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

public protocol OpenAppSettingsUseCase: Sendable {
    @MainActor
    func execute()
}

public extension OpenAppSettingsUseCase {
    @MainActor
    func callAsFunction() {
        execute()
    }
}

public final class OpenAppSettings: OpenAppSettingsUseCase {
    public init() {}

    @MainActor
    public func execute() {
        #if os(iOS)
        if AppConstants.isMobile {
            iosSettings()
        } else {
            if let url = URL(string: "x-apple.systempreferences:") {
                UIApplication.shared.open(url)
            }
        }
        #else
        macSettings()
        #endif
    }
}

private extension OpenAppSettings {
    #if os(macOS)
    @MainActor
    func macSettings() {
        if let url = URL(string: "x-apple.systempreferences:") {
            NSWorkspace.shared.open(url)
        }
    }
    #endif

    #if os(iOS)
    @MainActor
    func iosSettings() {
        if let settingsURL =
            URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared
                .open(settingsURL,
                      options: [:],
                      completionHandler: nil)
        }
    }
    #endif
}
