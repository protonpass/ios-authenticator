//
// ArrayExtensionsTests.swift
// Proton Authenticator - Created on 12/06/2026.
// Copyright (c) 2026 Proton Technologies AG
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

struct ArrayExtensionsTests {
    private struct Item: Identifiable {
        let id: String
    }

    @Test
    func `Same members in a different order match`() {
        let a = [Item(id: "1"), Item(id: "2"), Item(id: "3")]
        let b = [Item(id: "3"), Item(id: "1"), Item(id: "2")]
        #expect(a.hasSameMembers(as: b))
        #expect(b.hasSameMembers(as: a))
    }

    @Test
    func `Identical arrays match`() {
        let a = [Item(id: "1"), Item(id: "2")]
        #expect(a.hasSameMembers(as: a))
    }

    @Test
    func `A superset does not match (element added)`() {
        let snapshot = [Item(id: "1"), Item(id: "2")]
        let withNewItem = [Item(id: "1"), Item(id: "2"), Item(id: "3")]
        #expect(!snapshot.hasSameMembers(as: withNewItem))
        #expect(!withNewItem.hasSameMembers(as: snapshot))
    }

    @Test
    func `Disjoint arrays do not match`() {
        let a = [Item(id: "1"), Item(id: "2")]
        let b = [Item(id: "3"), Item(id: "4")]
        #expect(!a.hasSameMembers(as: b))
    }

    @Test
    func `Two empty arrays match`() {
        let a: [Item] = []
        let b: [Item] = []
        #expect(a.hasSameMembers(as: b))
    }
}
