//  
// LogManagerTests.swift
// Proton Authenticator - Created on 05/08/2025.
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
import SimplyPersist
import Testing
import Models
import SwiftData
@testable import DataLayer

@Suite(.tags(.tooling))
struct LogManagerTests {
    let sut: LoggerProtocol
    
    init() throws {
        let persistenceService = try PersistenceService(with: ModelConfiguration(for: LogEntryEntity.self,
                                                                                 isStoredInMemoryOnly: true))
        let localDataManager = MockLocalDataManager(persistentStorage: persistenceService)
        sut = LogManager(localDataManager: localDataManager)
    }
    
    @Test("Test removing bad logs")
    func removeBadLogs() async throws {
        
        let logs = [
            "Inserting entry from URI: /example",
            "Inserting and refreshing entry from parameters: id=1",
            "Some useful info and params: a=b",
            "User logged in",
            "Network request succeeded",
            "Database migration completed",
            "User logged in",
            "Network request succeeded",
            "Database migration completed",
            "User logged in",
            "Network request succeeded",
            "Database migration completed",
            "User logged in",
            "Network request succeeded",
            "Database migration completed"
        ]

        for log in logs {
            sut.log(.debug, category: .ui, log)
        }
        
        let logEntries = try await sut.fetchLogs(category: nil)
        #expect(logEntries.count == 12)
        #expect(logEntries.contains { !$0.message.contains("Inserting entry from URI:") })
        #expect(logEntries.contains { !$0.message.contains("Inserting and refreshing entry from parameters:") })
        #expect(logEntries.contains { !$0.message.contains("and params:") })
    }
    
    @Test("Test cleaning up exported logs by removing bad logs")
    func cleanUpLogs() async throws {
        
        let logs = [
            "Inserting entry from URI: /example",
            "Inserting and refreshing entry from parameters: id=1",
            "Some useful info and params: a=b",
            "User logged in",
            "Network request succeeded",
            "Database migration completed",
            "User logged in",
            "Network request succeeded",
            "Database migration completed",
            "User logged in",
            "Network request succeeded",
            "Database migration completed",
            "User logged in",
            "Network request succeeded",
            "Database migration completed"
        ]

        for log in logs {
            sut.log(.debug, category: .ui, log)
        }
        
        let content = try await sut.logsContent(category: nil)
        #expect(!content.contains( "Inserting entry from URI:"))
        #expect(!content.contains( "Inserting and refreshing entry from parameters:"))
        #expect(!content.contains("and params:"))
    }
}
