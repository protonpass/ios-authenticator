//  
// MockKeyProvider.swift
// Proton Authenticator - Created on 07/05/2025.
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

import DataLayer
import Foundation
import CryptoKit

final class MockKeyProvider: @unchecked Sendable, KeysProvider {
    let data: Data

    var dataKey = [String:Data]()

    init() {
        self.data = try! Data.random()
    }
    
    public func getSymmetricKey() throws -> SymmetricKey {
        return .init(data: data)
    }
    
    func get(keyId: String) throws -> Data {
        guard let keyData = dataKey[keyId] else {
            throw MockError.noKeyData
        }
        return keyData
    }
    
    func set(_ keyData: Data, for keyId: String) throws {
        dataKey[keyId] = keyData
    }
    
    func clear(keyId: String) throws {
        dataKey.removeValue(forKey: keyId)
    }
}

enum MockError: Error {
    case noKeyData
}
