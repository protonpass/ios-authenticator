//
// String+Extensions.swift
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

public extension StringProtocol {
    func separatedByGroup(_ charCount: Int, delimiter: Character) -> String {
        guard charCount > 0 else { return String(self) }

        var result = ""
        let reversedString = String(reversed())

        for (index, character) in reversedString.enumerated() {
            result.append(character)

            if (index + 1) % charCount == 0, index + 1 != reversedString.count {
                result.append(delimiter)
            }
        }

        return String(result.reversed())
    }
}

public extension String {
    var decodeHTMLAndPercent: String {
        let decodedHTML = decodingHTMLEntities()
        return decodedHTML.removingPercentEncoding ?? decodedHTML
    }

    private func decodingHTMLEntities() -> String {
        guard let data = data(using: .utf8) else { return self }

        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]

        if let attributedString = try? NSAttributedString(data: data, options: options, documentAttributes: nil) {
            return attributedString.string
        } else {
            return self
        }
    }
}

// MARK: - Variables

public extension StringProtocol {
    var isValidJSON: Bool {
        if let data = data(using: .utf8) {
            do {
                _ = try JSONSerialization.jsonObject(with: data, options: [])
                return true
            } catch {
                return false
            }
        }
        return false
    }
}
