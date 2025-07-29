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

#if os(iOS) || os(macOS) || os(tvOS) || targetEnvironment(macCatalyst)
import Foundation
import SwiftUI
import UniformTypeIdentifiers

public struct TextDocument: FileDocument, Transferable, Codable {
    public let title: String
    private let content: String

    public init(_ content: String = "") {
        title = TextDocument.exportFileName
        self.content = content
    }

    public static let readableContentTypes: [UTType] = [.text]

    public init(configuration: ReadConfiguration) throws {
        title = TextDocument.exportFileName
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

    public static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .plainText) { file in
            // Create temporary file
            let tempURL = URL.temporaryDirectory
                .appendingPathComponent(file.title)
                .appendingPathExtension("txt")

            // Write content to file
            try file.content.write(to: tempURL, atomically: true, encoding: .utf8)
            return SentTransferredFile(tempURL)
        } importing: { received in
            // This is required but won't be used for sharing
            let data = try Data(contentsOf: received.file)
            let content = String(data: data, encoding: .utf8) ?? ""
            return TextDocument(content)
        }

        // Add fallback data representation
        DataRepresentation(exportedContentType: .plainText) { file in
            Data(file.content.utf8)
        }
        .suggestedFileName { file in
            file.title
        }
    }

    static var exportFileName: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let currentDate = dateFormatter.string(from: .now)

        return "Proton_Authenticator_backup_\(currentDate)"
    }
}
#endif
