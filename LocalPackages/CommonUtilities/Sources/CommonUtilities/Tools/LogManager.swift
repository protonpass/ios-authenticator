//
// LogService.swift
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

import OSLog

public enum LogCategory: String, CaseIterable, Sendable {
    case system = "System"
    case network = "Network"
    case data = "Data"
    case database = "Database"
    case ui = "UI"
    case analytics = "Analytics"
}

public enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    case critical = "CRITICAL"
    
    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .error
        case .error: return .fault
        case .critical: return .fault
        }
    }
}

import SwiftData
import Foundation

struct LogEntry: Sendable {
    let timestamp: Date
    let level: String
    let message: String
    let category: String  // Stored as string for SwiftData compatibility
    let file: String
    let function: String
    let line: Int

    init(timestamp: Date = Date.now, level: String, message: String, category: LogCategory, file: String, function: String, line: Int) {
        self.timestamp = timestamp
        self.level = level
        self.message = message
        self.category = category.rawValue  // Store as string
        self.file = file
        self.function = function
        self.line = line
    }
}

@Model
final class LogEntryEntity {
    var timestamp: Date
    var level: String
    var message: String
    var category: String  // Stored as string for SwiftData compatibility
    var file: String
    var function: String
    var line: Int

    init(timestamp: Date = Date.now, level: String, message: String, category: LogCategory, file: String, function: String, line: Int) {
        self.timestamp = timestamp
        self.level = level
        self.message = message
        self.category = category.rawValue  // Store as string
        self.file = file
        self.function = function
        self.line = line
    }
}

public struct LogManagerConfiguration {
    public let logRetentionDays: Int
    public let maxLogEntries: Int
    public let saveInterval: TimeInterval
    public let batchSize: Int
    
    public init(logRetentionDays: Int, maxLogEntries: Int, saveInterval: TimeInterval, batchSize: Int) {
        self.logRetentionDays = logRetentionDays
        self.maxLogEntries = maxLogEntries
        self.saveInterval = saveInterval
        self.batchSize = batchSize
    }
    
    static var `default`: LogManagerConfiguration {
        LogManagerConfiguration(logRetentionDays: 3,
                                maxLogEntries: 5000,
                                saveInterval: 5,
                                batchSize: 10)
    }
}


import SwiftData
import Foundation
import OSLog
import Combine

public protocol LoggerProtocol: Sendable {
    
}

final class LogManager: LoggerProtocol {
    
    private let logRetentionDays = 7
    private let maxLogEntries = 5000
    private let saveInterval: TimeInterval = 5
    private let batchSize = 10
    
    private var logBuffer: [LogEntry] = []
    private let loggers: [LogCategory: Logger]
    
//    private let saveQueue = DispatchQueue(label: "LogSaveQueue", qos: .background)
//    private var saveTimer: Timer?
    
//    private var modelContext: ModelContext
    private nonisolated(unsafe) var saveTimerSubscription: Cancellable?
    
    private let subsystem: String

    init(subsystem: String = AppConstants.service) {
        self.subsystem = subsystem
//        let container = try! ModelContainer(for: LogEntry.self)
//        self.modelContext = ModelContext(container)
        loggers = LogCategory.allCases.reduce([LogCategory: Logger]()) { (dict, category) -> [LogCategory: Logger] in
            var dict = dict
               dict[category] =  Logger(subsystem: subsystem, category: category.rawValue)
               return dict
        }
//        startSaveTimer()
    }
    
    deinit {
        saveTimerSubscription?.cancel()
    }

//    // MARK: - Get Logger for Category
//    func logger(for category: LogCategory) -> Logger {
//        if let logger = loggers[category] {
//            return logger
//        } else {
//            let newLogger = Logger(subsystem: subsystem, category: category.rawValue)
//            loggers[category] = newLogger
//            return newLogger
//        }
//    }

    // MARK: - Log Message
    func log(_ level: LogLevel, category: LogCategory, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let logEntry = LogEntry(level: level.rawValue, message: message, category: category, file: file, function: function, line: line)
//        logBuffer.append(logEntry)
//
//        if logBuffer.count >= batchSize {
//            saveLogs()
//        }

        let logger = loggers[category]
        logger?.log(level: level.osLogType, "[\(category.rawValue)][\(level.rawValue)] \(message) (\(file):\(line) \(function))")
    }

    // MARK: - Save Logs
    private func saveLogs() {
        guard !logBuffer.isEmpty else { return }

//        saveQueue.async {
//            Task { @MainActor in
//                self.logBuffer.forEach { self.modelContext.insert($0) }
//                do {
//                    try self.modelContext.save()
//                    self.logBuffer.removeAll()
//                    self.cleanupOldLogs()
//                } catch {
//                    print("Failed to save logs: \(error.localizedDescription)")
//                }
//            }
//        }
    }

    // MARK: - Timer for Periodic Saving
    private func startSaveTimer() {
        saveTimerSubscription = Timer.publish(every: saveInterval, on: RunLoop.current, in: .common)
                   .autoconnect()
                   .sink { [weak self] _ in
                       self?.saveLogs()
                   }
    }

//    // MARK: - Fetch Logs by Category
//    func fetchLogs(category: LogCategory? = nil) -> [LogEntry] {
//        var descriptor: FetchDescriptor<LogEntry>
//        if let category {
//            descriptor = FetchDescriptor<LogEntry>(
//                predicate: #Predicate { $0.category == category.rawValue },
//                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
//            )
//        } else {
//            descriptor = FetchDescriptor<LogEntry>(
//                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
//            )
//        }
//        return (try? modelContext.fetch(descriptor)) ?? []
//    }
//
//    // MARK: - Export Logs (Per Category)
//    func exportLogs(category: LogCategory? = nil) -> URL? {
//        let logs = fetchLogs(category: category)
//        let logString = logs.map { log in
//            "[\(log.timestamp)] [\(log.level)] \(log.message)"
//        }.joined(separator: "\n")
//
//        let filename = category != nil ? "logs_\(category!.rawValue).txt" : "logs.txt"
//        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
//
//        do {
//            try logString.write(to: fileURL, atomically: true, encoding: .utf8)
//            deleteAllLogs(category: category)  // Clear logs after export
//            return fileURL
//        } catch {
//            print("Failed to export logs: \(error.localizedDescription)")
//            return nil
//        }
//    }
//
//    // MARK: - Cleanup Old Logs
//    private func cleanupOldLogs() {
//        let retentionDate = Calendar.current.date(byAdding: .day, value: -logRetentionDays, to: Date())!
//
//        let oldLogsDescriptor = FetchDescriptor<LogEntry>(
//            predicate: #Predicate { $0.timestamp < retentionDate }
//        )
//
//        Task { @MainActor in
//            do {
//                let oldLogs = try modelContext.fetch(oldLogsDescriptor)
//                oldLogs.forEach { modelContext.delete($0) }
//                
//                let totalCount = try modelContext.fetchCount(FetchDescriptor<LogEntry>())
//                if totalCount > maxLogEntries {
//                    let excessLogsDescriptor = FetchDescriptor<LogEntry>(
//                        sortBy: [SortDescriptor(\.timestamp, order: .forward)],
//                        fetchLimit: totalCount - maxLogEntries
//                    )
//                    let excessLogs = try modelContext.fetch(excessLogsDescriptor)
//                    excessLogs.forEach { modelContext.delete($0) }
//                }
//                
//                try modelContext.save()
//            } catch {
//                print("Failed to clean up logs: \(error.localizedDescription)")
//            }
//        }
//    }
//
//    // MARK: - Delete Logs (Optional: By Category)
//    private func deleteAllLogs(category: LogCategory? = nil) {
//        let fetchDescriptor: FetchDescriptor<LogEntry>
//        if let category {
//            fetchDescriptor = FetchDescriptor<LogEntry>(predicate: #Predicate { $0.category == category.rawValue })
//        } else {
//            fetchDescriptor = FetchDescriptor<LogEntry>()
//        }
//
//        Task { @MainActor in
//            do {
//                let logs = try modelContext.fetch(fetchDescriptor)
//                logs.forEach { modelContext.delete($0) }
//                try modelContext.save()
//            } catch {
//                print("Failed to delete logs: \(error.localizedDescription)")
//            }
//        }
//    }
}






//
//
//
//
//public protocol LoggerProtocol: Sendable {
//    var systemLogger: Logger { get }
//    var networkLogger: Logger { get }
//    var dataLogger: Logger { get }
//
//    func exportLogSinceLastBooted() -> [String]
//    func exportLastDayLogs() -> [String]
//}
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//public final class LogService: LoggerProtocol {
//    // Loggers for different categories
//    public let systemLogger: Logger
//    public let networkLogger: Logger
//    // Should be use for logging repos and services
//    public let dataLogger: Logger
//
//    private let subsystem: String
//
//    public init(subsystem: String = AppConstants.service) {
//        self.subsystem = subsystem
//        systemLogger = Logger(subsystem: subsystem, category: LogCategory.system.rawValue)
//        networkLogger = Logger(subsystem: subsystem, category: LogCategory.network.rawValue)
//        dataLogger = Logger(subsystem: subsystem, category: LogCategory.data.rawValue)
//    }
//
//    public func exportLogSinceLastBooted() -> [String] {
//        do {
//            let store = try OSLogStore(scope: .currentProcessIdentifier)
//            let position = store.position(timeIntervalSinceLatestBoot: 1)
//            let logs = try store
//                .getEntries(at: position)
//                .compactMap { $0 as? OSLogEntryLog }
//                .filter { $0.subsystem == subsystem }
//                .map { "[\($0.date.formatted())] [\($0.category)] \($0.composedMessage)" }
//            return logs
//        } catch {
//            return []
//        }
//    }
//
//    public func exportLastDayLogs() -> [String] {
//        do {
//            let store = try OSLogStore(scope: .currentProcessIdentifier)
//            let date = Date.now.addingTimeInterval(-24 * 3_600)
//            let position = store.position(date: date)
//
//            let logs = try store
//                .getEntries(at: position)
//                .compactMap { $0 as? OSLogEntryLog }
//                .filter { $0.subsystem == subsystem }
//                .map { "[\($0.date.formatted())] [\($0.category)] \($0.composedMessage)" }
//            return logs
//        } catch {
//            return []
//        }
//    }
//
//    public func fetch(since date: Date, predicateFormat: String) async throws -> [String] {
//        let store = try OSLogStore(scope: .currentProcessIdentifier)
//        let position = store.position(date: date)
//        let predicate = NSPredicate(format: predicateFormat)
//        let entries = try store.getEntries(at: position,
//                                           matching: predicate)
//
//        var logs: [String] = []
//        for entry in entries {
//            try Task.checkCancellation()
//            if let log = entry as? OSLogEntryLog {
//                logs.append("""
//                \(entry.date):\(log.subsystem):\
//                \(log.category):\(log.level.description): \
//                \(entry.composedMessage)\n
//                """)
//            } else {
//                logs.append("\(entry.date): \(entry.composedMessage)\n")
//            }
//        }
//
//        if logs.isEmpty { logs = [] }
//        return logs
//    }
//}
//
//private extension OSLogEntryLog.Level {
//    var description: String {
//        switch self {
//        case .undefined: "undefined"
//        case .debug: "debug"
//        case .info: "info"
//        case .notice: "notice"
//        case .error: "error"
//        case .fault: "fault"
//        @unknown default: "default"
//        }
//    }
//}
