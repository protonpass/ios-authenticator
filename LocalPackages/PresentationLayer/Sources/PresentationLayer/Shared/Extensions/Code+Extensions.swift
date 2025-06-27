//
// Code+Extensions.swift
// Proton Authenticator - Created on 27/06/2025.
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

import Models

extension Code {
    enum CodeType {
        case current, next
    }

    func displayedCode(for type: CodeType,
                       config: EntryCellConfiguration) -> String {
        var codeValue = type == .current ? current : next
        codeValue = config.hideEntryCode ?
            String(repeating: "•", count: codeValue.count) : codeValue

        return codeValue.count > 6 ?
            codeValue : codeValue.separatedByGroup(3, delimiter: " ")
    }
}
