//
// EntryUiModel.swift
// Proton Authenticator - Created on 17/02/2025.
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
import SwiftUI
import UniformTypeIdentifiers

public struct EntryUiModel: Sendable, Identifiable, Equatable, Hashable, Transferable, Codable,
    IdentifiableOrderedEntry {
    public let entry: Entry
    public let code: Code
    public let order: Int

    public var id: String {
        entry.id
    }

    public init(entry: Entry,
                code: Code,
                order: Int) {
        self.entry = entry
        self.code = code
        self.order = order
    }

    public func copy(newEntry: Entry) -> EntryUiModel {
        EntryUiModel(entry: newEntry, code: code, order: order)
    }

    public static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .entryUIModelType)
    }
}

public extension UTType {
    static let entryUIModelType = UTType(exportedAs: "me.proton.authenticator")
}

public extension EntryUiModel {
    func updateCode(_ code: Code) -> EntryUiModel {
        EntryUiModel(entry: entry, code: code, order: order)
    }

    func updateOrder(_ order: Int) -> EntryUiModel {
        EntryUiModel(entry: entry, code: code, order: order)
    }
}
