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

public struct EntryUiModel: Sendable, Identifiable, Equatable, Hashable, Codable {
    public var orderedEntry: OrderedEntry
    public let code: Code
    public let issuerInfo: AuthIssuerInfo?

    public var id: String {
        orderedEntry.id
    }

    public init(orderedEntry: OrderedEntry, code: Code, issuerInfo: AuthIssuerInfo?) {
        self.orderedEntry = orderedEntry
        self.code = code
        self.issuerInfo = issuerInfo
    }

    public func copy(newEntry: Entry) -> Self {
        Self(orderedEntry: orderedEntry.updateEntry(newEntry),
             code: code,
             issuerInfo: issuerInfo)
    }

    public func updateRemoteInfos(_ remoteId: String) -> Self {
        Self(orderedEntry: orderedEntry.updateRemoteInfos(remoteId),
             code: code,
             issuerInfo: issuerInfo)
    }
}

public extension EntryUiModel {
    func updateCode(_ code: Code) -> EntryUiModel {
        EntryUiModel(orderedEntry: orderedEntry,
                     code: code,
                     issuerInfo: issuerInfo)
    }

    func updateOrder(_ order: Int) -> EntryUiModel {
        EntryUiModel(orderedEntry: orderedEntry.updateOrder(order),
                     code: code,
                     issuerInfo: issuerInfo)
    }
}

public extension [EntryUiModel] {
    /// Removes duplicate entries (same `id`), keeping only the one with the newest `modifiedTime`.
    func deduplicatedByNewestModifiedTime() -> [EntryUiModel] {
        var seen = [String: Int]()
        var result = [EntryUiModel]()
        for entry in self {
            if let existingIndex = seen[entry.id] {
                if entry.orderedEntry.modifiedTime > result[existingIndex].orderedEntry.modifiedTime {
                    result[existingIndex] = entry
                }
            } else {
                seen[entry.id] = result.count
                result.append(entry)
            }
        }
        return result
    }
}
