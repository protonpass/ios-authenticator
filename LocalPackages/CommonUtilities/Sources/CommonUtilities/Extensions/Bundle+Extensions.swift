//
// Bundle+Extensions.swift
// Proton Authenticator - Created on 15/02/2025.
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

import Foundation

public extension Bundle {
    var versionNumber: String { string(forKey: "CFBundleShortVersionString") ?? "0.0.0" }
    var buildNumber: String { string(forKey: "CFBundleVersion") ?? "0" }
    var versionIdentifier: String? { string(forKey: "APP_VERSION_IDENTIFIER =
    var isQaBuild: Bool { bool(forKey: "IS_QA_BUILD =

    /// Get the full name of the current version e.g "1.0.0-dev" or "1.2.0"
    var fullAppVersionName: String {
        if let versionIdentifier, !versionIdentifier.isEmpty {
            return "\(versionNumber)-\(versionIdentifier)"
        }
        return versionNumber
    }

    var displayedAppVersion: String {
        let fullAppVersionName = Bundle.main.fullAppVersionName
        let buildNumber = Bundle.main.buildNumber
        return "\(fullAppVersionName) (\(buildNumber))"
    }
}

private extension Bundle {
    func string(forKey key: String) -> String? {
        infoDictionary?[key] as? String
    }

    /// Default to `false` if the key does not exist
    func bool(forKey key: String) -> Bool {
        let boolString = infoDictionary?[key] as? String
        return boolString == "YES"
    }
}
