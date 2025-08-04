//
// AppDelegate.swift
// Proton Authenticator - Created on 04/08/2025.
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
// along with Proton Pass. If not, see https://www.gnu.org/licenses/.

import FactoryKit
import PresentationLayer
#if os(iOS)
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    @LazyInjected(\UseCaseContainer.emptyTempDirectory)
    private var emptyTempDirectory

    func applicationWillTerminate(_ application: UIApplication) {
        emptyTempDirectory()
    }
}

#elseif os(macOS)
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    @LazyInjected(\UseCaseContainer.emptyTempDirectory)
    private var emptyTempDirectory

    func applicationWillTerminate(_ notification: Notification) {
        emptyTempDirectory()
    }
}
#endif
