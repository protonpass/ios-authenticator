//
// BackUpManager.swift
// Proton Authenticator - Created on 18/07/2025.
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
import Foundation
import Macro
import Models

public protocol BackUpServicing: Actor {
    func write(fileName: String, data: Data) throws
    func read(fileName: String) throws -> Data
    func getAllDocumentsData() throws -> [BackUpFileInfo]
}

public struct BackUpFileInfo: Sendable, Equatable {
    public let name: String
    public let creationDate: Date
    public let url: URL

    init(name: String, creationDate: Date, url: URL) {
        self.name = name
        self.creationDate = creationDate
        self.url = url
    }

    public var displayedDate: String {
        creationDate.formattedBackupDate
    }
}

public actor BackUpManager: BackUpServicing {
    private let coordinator: NSFileCoordinator
    private let maxBackupCount: Int

    public init(maxBackupCount: Int = 5) {
        coordinator = NSFileCoordinator()
        self.maxBackupCount = maxBackupCount
    }

    private var containerURL: URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: AppConstants.icloudContainerIdentifier)
    }

    private var documentURL: URL? {
        let documentsFolderURL = containerURL?.appendingPathComponent("Documents")
        return documentsFolderURL
    }

    public func write(fileName: String, data: Data) throws {
        guard let documentURL else {
            throw AuthError.backup(.noDestinationFolder)
        }

        try enforceFileRotationPolicy()

        let targetURL = documentURL.appendingPathComponent(fileName)
        var coordinationError: NSError?
        var writeError: Error?

        coordinator
            .coordinate(writingItemAt: targetURL, options: [.forReplacing], error: &coordinationError) { url in
                do {
                    try data.write(to: url, options: .atomic)
                } catch {
                    writeError = error
                }
            }

        if let error = writeError {
            throw error
        }

        if let coordinationError {
            throw coordinationError
        }
    }

    public func delete(fileName: String) throws {
        guard let documentURL else {
            throw AuthError.backup(.noDestinationFolder)
        }

        let targetURL = documentURL.appendingPathComponent(fileName)
        try coordinatedDelete(at: targetURL)
    }

    public func read(fileName: String) throws -> Data {
        guard let documentURL else {
            throw AuthError.backup(.noDestinationFolder)
        }
        let targetURL = documentURL.appendingPathComponent(fileName)
        var coordinationError: NSError?
        var data: Data?
        var readError: Error?

        coordinator.coordinate(readingItemAt: targetURL, options: [], error: &coordinationError) { url in
            do {
                data = try Data(contentsOf: url)
            } catch {
                readError = error
            }
        }

        if let error = readError {
            throw error
        }

        if let coordinationError {
            throw coordinationError
        }

        // Make sure the data read is not empty
        guard let data else {
            throw AuthError.backup(.noData)
        }

        return data
    }

    public func getAllDocumentsData() throws -> [BackUpFileInfo] {
        try getAllFilesWithMetadata()
    }

    public func getAllDocumentsFileNames() throws -> [String]? {
        guard let documentURL else {
            throw AuthError.backup(.noDestinationFolder)
        }

        let fileURLs = try FileManager.default.contentsOfDirectory(at: documentURL,
                                                                   includingPropertiesForKeys: [.isDirectoryKey],
                                                                   options: .skipsHiddenFiles)

        return fileURLs.compactMap { url in
            guard let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey]),
                  let isDirectory = resourceValues.isDirectory,
                  !isDirectory else {
                return nil
            }
            return url.lastPathComponent
        }
    }
}

private extension BackUpManager {
    func enforceFileRotationPolicy() throws {
        let files = try getAllFilesWithMetadata()

        guard files.count >= maxBackupCount else {
            return
        }

        let filesToDelete = files.count - maxBackupCount + 1

        for index in 0..<filesToDelete {
            try coordinatedDelete(at: files[index].url)
        }
    }

    func getAllFilesWithMetadata() throws -> [BackUpFileInfo] {
        guard let documentURL else {
            throw AuthError.backup(.noDestinationFolder)
        }

        let fileURLs = try FileManager.default.contentsOfDirectory(at: documentURL,
                                                                   includingPropertiesForKeys: [
                                                                       .creationDateKey,
                                                                       .isDirectoryKey
                                                                   ],
                                                                   options: .skipsHiddenFiles)

        let sortedResults: [BackUpFileInfo] = try fileURLs.compactMap { url -> BackUpFileInfo? in
            let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey, .creationDateKey])
            guard let isDirectory = resourceValues.isDirectory,
                  !isDirectory,
                  let creationDate = resourceValues.creationDate else {
                return nil
            }
            return BackUpFileInfo(name: url.lastPathComponent, creationDate: creationDate, url: url)
        }
        .sorted { $0.creationDate < $1.creationDate }

        return sortedResults
    }

    func coordinatedDelete(at url: URL) throws {
        var coordinationError: NSError?
        var operationError: Error?

        coordinator
            .coordinate(writingItemAt: url, options: [.forDeleting], error: &coordinationError) { coordinatedURL in
                do {
                    try FileManager.default.removeItem(at: coordinatedURL)
                } catch {
                    operationError = error
                }
            }

        if let error = operationError {
            throw error
        }

        if let coordinationError {
            throw coordinationError
        }
    }
}

private extension Date {
    var formattedBackupDate: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current

        if calendar.isDateInToday(self) || calendar.isDateInYesterday(self) {
            formatter.doesRelativeDateFormatting = true
            formatter.dateStyle = .short
            formatter.timeStyle = .short

            // This will automatically use "Today" and "Yesterday" in the user's language
            let dateString = formatter.string(from: self)

            // Some languages might format this differently, so we need to handle it
            if calendar.isDateInToday(self), !dateString.localizedCaseInsensitiveContains("today") {
                return #localized("Today, %@", formatter.string(from: self))
            } else if calendar.isDateInYesterday(self), !dateString.localizedCaseInsensitiveContains("yesterday") {
                return #localized("Yesterday, %@", formatter.string(from: self))
            }
            return dateString
        } else {
            formatter.doesRelativeDateFormatting = false
            if calendar.isDate(self, equalTo: Date(), toGranularity: .year) {
                formatter.setLocalizedDateFormatFromTemplate("MMM d, HH:mm")
            } else {
                formatter.setLocalizedDateFormatFromTemplate("MMM d yyyy, HH:mm")
            }
            return formatter.string(from: self)
        }
    }
}
