//
// ProtonProduct.swift
// Proton Authenticator - Created on 20/02/2025.
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

public enum ProtonProduct: Sendable, CaseIterable {
    case pass, vpn, mail, drive, calendar
}

public extension ProtonProduct {
    var name: String {
        switch self {
        case .pass: "Proton Pass"
        case .vpn: "Proton VPN"
        case .mail: "Proton Mail"
        case .drive: "Proton Drive"
        case .calendar: "Proton Calendar"
        }
    }

    var iOSAppBundleId: String {
        switch self {
        case .pass: "protonpass"
        case .vpn: "protonvpn"
        case .mail: "ch.protonmail.protonmail.mailto"
        case .drive: "ch.protonmail.drive"
        case .calendar: "protoncalendar"
        }
    }

    var iOSAppUrl: String {
        switch self {
        case .pass: "itms-apps://itunes.apple.com/app/id6443490629"
        case .vpn: "itms-apps://itunes.apple.com/app/id1437005085"
        case .mail: "itms-apps://itunes.apple.com/app/id979659905"
        case .drive: "itms-apps://itunes.apple.com/app/id1509667851"
        case .calendar: "itms-apps://itunes.apple.com/app/id1514709943"
        }
    }

    var homepageUrl: String {
        switch self {
        case .pass: "https://proton.me/pass"
        case .vpn: "https://proton.me/vpn"
        case .mail: "https://proton.me/mail"
        case .drive: "https://proton.me/drive"
        case .calendar: "https://proton.me/calendar"
        }
    }
}
