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

public enum LogCategory: String {
    case system
    case network
    case data
}

public protocol LoggerProtocol: Sendable {
    var systemLogger: Logger { get }
    var networkLogger: Logger { get }
    var dataLogger: Logger { get }

    func exportLogSinceLastBooted() -> [String]
    func exportLastDayLogs() -> [String]
}

public final class LogService: LoggerProtocol {
    // Loggers for different categories
    public let systemLogger: Logger
    public let networkLogger: Logger
    // Should be use for logging repos and services
    public let dataLogger: Logger

    private let subsystem: String

    public init(subsystem: String = AppConstants.service) {
        self.subsystem = subsystem
        systemLogger = Logger(subsystem: subsystem, category: LogCategory.system.rawValue)
        networkLogger = Logger(subsystem: subsystem, category: LogCategory.network.rawValue)
        dataLogger = Logger(subsystem: subsystem, category: LogCategory.data.rawValue)
    }

    public func exportLogSinceLastBooted() -> [String] {
        do {
            let store = try OSLogStore(scope: .currentProcessIdentifier)
            let position = store.position(timeIntervalSinceLatestBoot: 1)
            let logs = try store
                .getEntries(at: position)
                .compactMap { $0 as? OSLogEntryLog }
                .filter { $0.subsystem == subsystem }
                .map { "[\($0.date.formatted())] [\($0.category)] \($0.composedMessage)" }
            return logs
        } catch {
            return []
        }
    }

    public func exportLastDayLogs() -> [String] {
        do {
            let store = try OSLogStore(scope: .currentProcessIdentifier)
            let date = Date.now.addingTimeInterval(-24 * 3_600)
            let position = store.position(date: date)

            let logs = try store
                .getEntries(at: position)
                .compactMap { $0 as? OSLogEntryLog }
                .filter { $0.subsystem == subsystem }
                .map { "[\($0.date.formatted())] [\($0.category)] \($0.composedMessage)" }
            return logs
        } catch {
            return []
        }
    }

    public func fetch(since date: Date, predicateFormat: String) async throws -> [String] {
        let store = try OSLogStore(scope: .currentProcessIdentifier)
        let position = store.position(date: date)
        let predicate = NSPredicate(format: predicateFormat)
        let entries = try store.getEntries(at: position,
                                           matching: predicate)

        var logs: [String] = []
        for entry in entries {
            try Task.checkCancellation()
            if let log = entry as? OSLogEntryLog {
                logs.append("""
                \(entry.date):\(log.subsystem):\
                \(log.category):\(log.level.description): \
                \(entry.composedMessage)\n
                """)
            } else {
                logs.append("\(entry.date): \(entry.composedMessage)\n")
            }
        }

        if logs.isEmpty { logs = [] }
        return logs
    }
}

private extension OSLogEntryLog.Level {
    var description: String {
        switch self {
        case .undefined: "undefined"
        case .debug: "debug"
        case .info: "info"
        case .notice: "notice"
        case .error: "error"
        case .fault: "fault"
        @unknown default: "default"
        }
    }
}
