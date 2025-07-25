//  
// EncryptedUserDataEntity.swift
// Proton Authenticator - Created on 25/07/2025.
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
import SwiftData

@Model
public final class EncryptedUserDataEntity: Equatable, Hashable, @unchecked Sendable {
    public private(set) var id: String = UUID().uuidString
    public private(set) var modifiedTime: TimeInterval = Date.now.timeIntervalSince1970
    public private(set) var encryptedData = Data()

    public init(id: String, encryptedData: Data, modifiedTime: TimeInterval = Date.now.timeIntervalSince1970) {
        self.id = id
        self.modifiedTime = modifiedTime
        self.encryptedData = encryptedData
    }

    public func updateEncryptedData(_ encryptedData: Data) {
        self.encryptedData = encryptedData
        modifiedTime = Date.now.timeIntervalSince1970
    }
}

