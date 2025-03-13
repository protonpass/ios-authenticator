//
// StringExtensionsTests.swift
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

import CommonUtilities
import Testing

struct StringExtensionsTests {
    // Example usage
    let jsonString = """
    {
        "name": "John",
        "age": 30
    }
    """

    @Test("Separated by group")
    func separatedByGroup() async throws {
        #expect("123456".separatedByGroup(3, delimiter: " ") == "123 456")
        #expect("1234567".separatedByGroup(3, delimiter: " ") == "1 234 567")
        #expect("12345678".separatedByGroup(3, delimiter: " ") == "12 345 678")
        #expect("123456789".separatedByGroup(3, delimiter: " ") == "123 456 789")
    }

    @Test("Check valid json string")
    func validJson() async throws {
        #expect(jsonString.isValidJSON == true)
    }

    @Test("Check invalid json string")
    func invalidJson() async throws {
        #expect("plop".isValidJSON == false)
    }
}
