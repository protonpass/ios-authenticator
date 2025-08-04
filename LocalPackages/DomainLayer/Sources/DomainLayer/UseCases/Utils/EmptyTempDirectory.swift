//
// EmptyTempDirectory.swift
// Proton Authenticator - Created on 04/08/2025.
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

import DataLayer
import Foundation

public protocol EmptyTempDirectoryUseCase: Sendable {
    func execute()
}

public extension EmptyTempDirectoryUseCase {
    func callAsFunction() {
        execute()
    }
}

public final class EmptyTempDirectory: EmptyTempDirectoryUseCase {
    private let logger: any LoggerProtocol

    public init(logger: any LoggerProtocol) {
        self.logger = logger
    }

    public func execute() {
        logger.log(.debug, category: .data, "Emptying temp directory")
        let fileManager = FileManager.default
        do {
            let tempUrl = fileManager.temporaryDirectory
            let items = try fileManager.contentsOfDirectory(at: tempUrl,
                                                            includingPropertiesForKeys: nil,
                                                            options: [])
            for item in items {
                try fileManager.removeItem(at: item)
            }
            logger.log(.debug, category: .data, "Emptied temp directory")
        } catch {
            logger.log(.error, category: .data, "Failed to empty temp directory")
        }
    }
}
