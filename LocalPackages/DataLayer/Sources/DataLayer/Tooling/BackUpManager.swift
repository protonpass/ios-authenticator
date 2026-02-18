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

import Foundation
import Macro
import Models
import UIKit

@MainActor
public protocol BackUpServicing: Sendable {
    func write(data: Data) throws
    func read(fileName: String) throws -> Data
    func getAllDocumentsData() throws -> [BackUpFileInfo]
    // periphery:ignore
    func delete(fileName: String) throws
    func deleteAllBackupFiles() throws
    func openBackupFolder()
    func setDestinationFolder(_ url: URL)
    func resolveDestinationFolder(from bookmarkData: Data) throws -> URL
    func clearDestinationFolder()
}

public struct BackUpFileInfo: Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let creationDate: Date
    public let url: URL

    init(id: String = UUID().uuidString, name: String, creationDate: Date, url: URL) {
        self.id = id
        self.name = name
        self.creationDate = creationDate
        self.url = url
    }

    public var displayedDate: String {
        creationDate.formattedBackupDate
    }
}

@MainActor
public final class BackUpManager: BackUpServicing {
    private let coordinator: NSFileCoordinator
    private let maxBackupCount: Int
    private let dateFormatter: DateFormatter
    private var documentURL: URL?

    public init(maxBackupCount: Int = 5) {
        coordinator = NSFileCoordinator()
        self.maxBackupCount = maxBackupCount
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
    }

    public func setDestinationFolder(_ url: URL) {
        documentURL = url
    }

    public func resolveDestinationFolder(from bookmarkData: Data) throws -> URL {
        var isStale = false
        let url = try URL(resolvingBookmarkData: bookmarkData,
                          options: [],
                          relativeTo: nil,
                          bookmarkDataIsStale: &isStale)
        if isStale {
            throw AuthError.backup(.staleBookmark)
        }
        documentURL = url
        return url
    }

    public func clearDestinationFolder() {
        documentURL = nil
    }

    public func write(data: Data) throws {
        guard let documentURL else {
            throw AuthError.backup(.noDestinationFolder)
        }

        try withSecurityScopedAccess(to: documentURL) {
            let todayFileName = getTodaysBackupFileName()
            let targetURL = documentURL.appendingPathComponent(todayFileName)

            if FileManager.default.fileExists(atPath: targetURL.path) {
                try coordinatedWrite(at: targetURL) { url in
                    try data.write(to: url, options: .atomic)
                }
            } else {
                try enforceFileRotationPolicy()
                try coordinatedWrite(at: targetURL) { url in
                    try data.write(to: url, options: .atomic)
                }
            }
        }
    }

    public func read(fileName: String) throws -> Data {
        guard let documentURL else {
            throw AuthError.backup(.noDestinationFolder)
        }

        return try withSecurityScopedAccess(to: documentURL) {
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

            guard let data else {
                throw AuthError.backup(.noData)
            }

            return data
        }
    }

    public func deleteAllBackupFiles() throws {
        guard let documentURL else {
            return
        }

        try withSecurityScopedAccess(to: documentURL) {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: documentURL,
                                                                       includingPropertiesForKeys: nil,
                                                                       options: [])

            for fileURL in fileURLs {
                try FileManager.default.removeItem(at: fileURL)
            }
        }
    }

    public func openBackupFolder() {
        guard let documentURL else {
            return
        }

        if let filesAppURL = URL(string: "shareddocuments://\(documentURL.path)") {
            if UIApplication.shared.canOpenURL(filesAppURL) {
                UIApplication.shared.open(filesAppURL)
            }
        }
    }

    public func getAllDocumentsData() throws -> [BackUpFileInfo] {
        guard let documentURL else {
            throw AuthError.backup(.noDestinationFolder)
        }

        return try withSecurityScopedAccess(to: documentURL) {
            try getAllFilesWithMetadata().sorted { $0.creationDate > $1.creationDate }
        }
    }

    // periphery:ignore
    public func delete(fileName: String) throws {
        guard let documentURL else {
            throw AuthError.backup(.noDestinationFolder)
        }

        try withSecurityScopedAccess(to: documentURL) {
            let targetURL = documentURL.appendingPathComponent(fileName)
            try coordinatedDelete(at: targetURL)
        }
    }
}

private extension BackUpManager {
    func withSecurityScopedAccess<T>(to url: URL, body: () throws -> T) rethrows -> T {
        let didStart = url.startAccessingSecurityScopedResource()
        defer {
            if didStart {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try body()
    }

    func getTodaysBackupFileName() -> String {
        let todayString = dateFormatter.string(from: Date())
        return "Proton_Authenticator_backup_\(todayString).json"
    }

    func enforceFileRotationPolicy() throws {
        let files = try getAllFilesWithMetadata().sorted { $0.creationDate < $1.creationDate }

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

        return try fileURLs.compactMap { url -> BackUpFileInfo? in
            let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey, .creationDateKey])
            guard let isDirectory = resourceValues.isDirectory,
                  !isDirectory,
                  let creationDate = resourceValues.creationDate else {
                return nil
            }
            return BackUpFileInfo(name: url.lastPathComponent, creationDate: creationDate, url: url)
        }
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

    func coordinatedWrite(at url: URL, block: (URL) throws -> Void) throws {
        var coordinationError: NSError?
        var operationError: Error?

        coordinator
            .coordinate(writingItemAt: url,
                        options: [.forReplacing],
                        error: &coordinationError) { coordinatedURL in
                do {
                    try block(coordinatedURL)
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

    // periphery:ignore
    func getAllDocumentsFileNames() throws -> [String]? {
        guard let documentURL else {
            throw AuthError.backup(.noDestinationFolder)
        }

        let fileURLs = try FileManager.default.contentsOfDirectory(at: documentURL,
                                                                   includingPropertiesForKeys: [
                                                                       .isDirectoryKey,
                                                                       .contentModificationDateKey
                                                                   ],
                                                                   options: .skipsHiddenFiles)
        return fileURLs.compactMap { url -> (String, Date)? in
            guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey]),
                  values.isDirectory == false,
                  let date = values.contentModificationDate else { return nil }
            return (url.lastPathComponent, date)
        }
        .sorted { $0.1 > $1.1 }
        .map(\.0)
    }
}

private extension Date {
    var formattedBackupDate: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        let isToday = calendar.isDateInToday(self)
        let isYesterday = calendar.isDateInYesterday(self)

        if isToday || isYesterday {
            formatter.doesRelativeDateFormatting = true
            formatter.dateStyle = .short
            formatter.timeStyle = .short

            return formatter.string(from: self)
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
