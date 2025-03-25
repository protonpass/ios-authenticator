//
// TextDocument.swift
// Proton Authenticator - Created on 20/03/2025.
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

public struct TextDocument: FileDocument {
    private let content: String

    public init(_ content: String = "") {
        self.content = content
    }

    public static let readableContentTypes: [UTType] = [.text]

    public init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents,
           let newContent = String(data: data, encoding: .utf8) {
            content = newContent
        } else {
            assertionFailure("Failed to UTF8 decode")
            content = ""
        }
    }

    public func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = Data(content.utf8)
        return FileWrapper(regularFileWithContents: data)
    }
}
