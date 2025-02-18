//
// EntriesViewModel.swift
// Proton Authenticator - Created on 10/02/2025.
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
import Models

@Observable @MainActor
final class EntriesViewModel {
    private(set) var entries: [Entry] = []
    var search = ""

    @ObservationIgnored
    private let bundle: Bundle
    @ObservationIgnored
    private let userDefaults: UserDefaults

    init(bundle: Bundle = .main,
         userDefaults: UserDefaults = kSharedUserDefaults) {
        self.bundle = bundle
        self.userDefaults = userDefaults
    }
}

extension EntriesViewModel {
    func setUp() async {
        if !mockEntries() {
            // Fetch real data
        }
    }
}

private extension EntriesViewModel {
    func mockEntries() -> Bool {
        guard bundle.isQaBuild, userDefaults.bool(forKey: AppConstants.QA.mockEntriesDisplay) else {
            return false
        }
        let count = max(5, userDefaults.integer(forKey: AppConstants.QA.mockEntriesCount))

        var entries = [Entry]()
        for index in 0..<count {
            entries.append(.init(name: "Test #\(index)",
                                 uri: "otpauth://totp/SimpleLogin:john.doe\(index)%40example.com?secret=CKTQQJVWT5IXTGD\(index)&amp;issuer=SimpleLogin",
                                 period: 30,
                                 type: .totp,
                                 note: "Note #\(index)"))
        }

        self.entries = entries
        return true
    }
}
