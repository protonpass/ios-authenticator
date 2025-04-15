//
// LogManager.swift
// Proton Authenticator - Created on 10/03/2025.
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
//

import Combine
import CommonUtilities
import Foundation
import os
import OSLog
import SimplyPersist
import SwiftData

public enum LogCategory: String, CaseIterable, Sendable, Codable {
    case system = "System"
    case network = "Network"
    case data = "Data"
    case database = "Database"
    case ui = "UI"
    case analytics = "Analytics"
}

public enum LogLevel: String, Sendable, Codable {
    // info: Call this function to capture information that may be helpful, but isn’t essential, for troubleshooting.
    case info = "INFO"
    // debug: Debug-level messages to use in a development environment while actively debugging.
    case debug = "DEBUG"
    // error: Error-level messages for reporting critical errors and failures.
    case error = "ERROR"
    // warning: Warning-level messages for reporting unexpected non-fatal failures.
    case warning = "WARNING"
    // critical: messages for capturing system-level or multi-process errors only.
    case critical = "CRITICAL"

    var osLogType: OSLogType {
        switch self {
        case .debug: .debug
        case .info: .info
        case .warning: .error
        case .error: .fault
        case .critical: .fault
        }
    }
}

public struct LogManagerConfiguration: Sendable {
    public let maxLogEntries: Int
    public let saveInterval: TimeInterval
    public let batchSize: Int

    public init(maxLogEntries: Int, saveInterval: TimeInterval, batchSize: Int) {
        self.maxLogEntries = maxLogEntries
        self.saveInterval = saveInterval
        self.batchSize = batchSize
    }

    public static var `default`: LogManagerConfiguration {
        LogManagerConfiguration(maxLogEntries: 5_000,
                                saveInterval: 5,
                                batchSize: 10)
    }
}

// swiftlint:disable function_parameter_count line_length
public protocol LoggerProtocol: Sendable {
    nonisolated func log(_ level: LogLevel,
                         category: LogCategory,
                         _ message: String,
                         file: String,
                         function: String,
                         line: Int)
    func exportLogs(category: LogCategory?) async -> URL?
}

public extension LoggerProtocol {
    nonisolated func log(_ level: LogLevel,
                         category: LogCategory,
                         _ message: String,
                         file: String = #file,
                         function: String = #function,
                         line: Int = #line) {
        log(level, category: category, message, file: file, function: function, line: line)
    }
}

public final actor LogManager: LoggerProtocol {
    private let configuration: LogManagerConfiguration
    private let loggers: [LogCategory: Logger]
    private let persistentStorage: any PersistenceServicing
    private let subsystem: String

    private var logBuffer: [LogEntry] = []
    private nonisolated(unsafe) var saveTimerSubscription: Cancellable?

    private var saveLogsTask: Task<Void, Never>?

    public init(subsystem: String = AppConstants.service,
                configuration: LogManagerConfiguration = .default,
                persistentStorage: any PersistenceServicing) {
        self.subsystem = subsystem
        self.persistentStorage = persistentStorage
        self.configuration = configuration

        loggers = LogCategory.allCases.reduce(into: [LogCategory: Logger]()) { dict, category in
            var dict = dict
            dict[category] = Logger(subsystem: subsystem, category: category.rawValue)
        }
        startSaveTimer()
    }

    deinit {
        saveTimerSubscription?.cancel()
    }

    public nonisolated func log(_ level: LogLevel,
                                category: LogCategory,
                                _ message: String,
                                file: String = #file,
                                function: String = #function,
                                line: Int = #line) {
        let logEntry = LogEntry(level: level,
                                message: message,
                                category: category,
                                file: file,
                                function: function,
                                line: line)
        Task {
            await log(logEntry: logEntry)
        }
    }

    // MARK: - Fetch Logs by Category

    func fetchLogs(category: LogCategory? = nil) async throws -> [LogEntryEntity] {
        let descriptor = if let category {
            FetchDescriptor<LogEntryEntity>(predicate: #Predicate { $0.category == category.rawValue },
                                            sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        } else {
            FetchDescriptor<LogEntryEntity>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        }
        return try await persistentStorage.fetch(fetchDescriptor: descriptor)
    }

    // MARK: - Export Logs (Per Category)

    public func exportLogs(category: LogCategory? = nil) async -> URL? {
        do {
            let logs = try await fetchLogs(category: category)
            let logString = logs.map { log in
                "[\(log.timestamp)] [\(log.level)] \(log.message)"
            }
            .joined(separator: "\n")

            let filename = if let category {
                "logs_\(category.rawValue).txt"
            } else {
                "logs.txt"
            }
            let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

            try logString.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Failed to export logs: \(error.localizedDescription)")
            return nil
        }
    }
}

private extension LogManager {
    // MARK: - Timer for Periodic Saving

    nonisolated func startSaveTimer() {
        saveTimerSubscription = Timer.publish(every: configuration.saveInterval, on: RunLoop.current, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                Task {
                    await saveLogs()
                }
            }
    }

    // MARK: - Save Logs

    func saveLogs() {
        guard !logBuffer.isEmpty,
              saveLogsTask == nil
        else { return }

        saveLogsTask = Task {
            defer { saveLogsTask = nil }
            do {
                let entities = logBuffer.toEntities
                try await persistentStorage.batchSave(content: entities)
                logBuffer.removeAll()
                try await cleanupOldLogs()
            } catch {
                print("Failed to save logs: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Log Message

    func log(logEntry: LogEntry) {
        logBuffer.append(logEntry)

        if logBuffer.count >= configuration.batchSize {
            saveLogs()
        }

        let logger = loggers[logEntry.category]
        logger?.log(level: logEntry.level.osLogType,
                    "[\(logEntry.category.rawValue)][\(logEntry.level.rawValue)] \(logEntry.message) (\(logEntry.file):\(logEntry.line) \(logEntry.function))")
    }

    // MARK: - Cleanup Old Logs

    func cleanupOldLogs() async throws {
        let totalCount = try await persistentStorage.count(LogEntryEntity.self)
        if totalCount > configuration.maxLogEntries {
            var excessLogsDescriptor =
                FetchDescriptor<LogEntryEntity>(sortBy: [SortDescriptor(\.timestamp, order: .forward)])
            excessLogsDescriptor.fetchLimit = totalCount - configuration.maxLogEntries

            let excessLogs: [LogEntryEntity] = try await persistentStorage
                .fetch(fetchDescriptor: excessLogsDescriptor)
            try await persistentStorage.delete(datas: excessLogs)
        }
    }

    // MARK: - Delete Logs (Optional: By Category)

    func deleteAllLogs(category: LogCategory? = nil) async throws {
        let fetchDescriptor = if let category {
            FetchDescriptor<LogEntryEntity>(predicate: #Predicate { $0.category == category.rawValue })
        } else {
            FetchDescriptor<LogEntryEntity>()
        }
        let logs = try await persistentStorage.fetch(fetchDescriptor: fetchDescriptor)
        try await persistentStorage.delete(datas: logs)
    }
}

// MARK: - Log models

public struct LogEntry: Sendable {
    let timestamp: Date
    let level: LogLevel
    let message: String
    let category: LogCategory
    let file: String
    let function: String
    let line: Int

    init(timestamp: Date = Date.now,
         level: LogLevel,
         message: String,
         category: LogCategory,
         file: String,
         function: String,
         line: Int) {
        self.timestamp = timestamp
        self.level = level
        self.message = message
        self.category = category
        self.file = file
        self.function = function
        self.line = line
    }
}

@Model
public final class LogEntryEntity: @unchecked Sendable {
    var timestamp: Date
    var level: String
    var message: String
    var category: String // Stored as string for SwiftData compatibility
    var file: String
    var function: String
    var line: Int

    init(timestamp: Date = Date.now,
         level: String,
         message: String,
         category: LogCategory,
         file: String,
         function: String,
         line: Int) {
        self.timestamp = timestamp
        self.level = level
        self.message = message
        self.category = category.rawValue // Store as string
        self.file = file
        self.function = function
        self.line = line
    }
}

private extension [LogEntry] {
    var toEntities: [LogEntryEntity] {
        map(\.toEntity)
    }
}

private extension LogEntry {
    var toEntity: LogEntryEntity {
        .init(timestamp: timestamp,
              level: level.rawValue,
              message: message,
              category: category,
              file: file,
              function: function,
              line: line)
    }
}

// swiftlint:enable function_parameter_count line_length
