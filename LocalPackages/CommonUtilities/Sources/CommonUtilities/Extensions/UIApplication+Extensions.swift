//
// UIApplication+Extensions.swift
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
// along with Proton Authenticator. If not, see https://www.gnu.org/licenses/.

#if os(iOS)
import Foundation
import SwiftUI

public extension UIApplication {
    static var topPresentedViewController: UIViewController? {
        guard let rootViewController = UIApplication.shared
            .connectedScenes.lazy
            .compactMap({ $0.activationState == .foregroundActive ? ($0 as? UIWindowScene) : nil })
            .first(where: { $0.keyWindow != nil })?
            .keyWindow?
            .rootViewController
        else {
            return nil
        }

        var topController = rootViewController

        while let presentedViewController = topController.presentedViewController {
            topController = presentedViewController
        }

        return topController
    }
}
#endif
