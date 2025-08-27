//
// KeyManager.swift
// Proton Authenticator - Created on 30/04/2025.
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
import CryptoKit
import Foundation
import Models
@preconcurrency import ProtonCoreKeymaker

public protocol KeysProvider: Sendable {
    func getSymmetricKey() throws -> SymmetricKey

    func get(keyId: String) throws -> Data
    func set(_ keyData: Data, for keyId: String) throws
    func clear(keyId: String, isSynced: Bool) throws
}

public extension KeysProvider {
    func clear(keyId: String, isSynced: Bool = true) throws {
        try clear(keyId: keyId, isSynced: isSynced)
    }
}

public protocol MainKeyProvider: Sendable, AnyObject {
    var mainKey: MainKey? { get }
}

extension Keymaker: @unchecked @retroactive Sendable, MainKeyProvider {
    override public convenience init() {
        let keychain = CoreKeychain()
        let locker = Autolocker(lockTimeProvider: keychain)
        self.init(autolocker: locker, keychain: keychain)
    }
}

final class CoreKeychain: Keychain, @unchecked Sendable {
    init() {
        super.init(service: "me.proton.authenticator", accessGroup: AppConstants.keychainGroup)
    }
}

extension CoreKeychain: SettingsProvider {
    private static let LockTimeKey = "AuthAccount.LockTimeKey"

    var lockTime: AutolockTimeout {
        get {
            guard let string = try? stringOrError(forKey: Self.LockTimeKey), let intValue = Int(string) else {
                return .never
            }
            return AutolockTimeout(rawValue: intValue)
        }
        set {
            do {
                try setOrError(String(newValue.rawValue), forKey: Self.LockTimeKey)
            } catch {
                print("Failed to set lockTime with error: \(error)")
            }
        }
    }
}

public final class KeysManager: KeysProvider {
    private let keychain: any KeychainServicing
    private let keyMaker: any MainKeyProvider
    private let keychainKey = "SymmetricKey"

    public init(keychain: any KeychainServicing,
                keyMaker: any MainKeyProvider = Keymaker()) {
        self.keychain = keychain
        self.keyMaker = keyMaker
    }

    public func getSymmetricKey() throws -> SymmetricKey {
        guard let mainKey = keyMaker.mainKey else {
            throw AuthError.generic(.mainKeyNotFound)
        }

        // At this point either migration is done or no key is generated (first installation)
        // so we proceed as normal (get if exist and random if not)
        if let lockedSymmetricKeyData: Data = try? keychain.get(keyId: keychainKey, isSynced: true) {
            try migrationSymmetricKeyToUnsync(lockedSymmetricKeyData)
            return try unlockSymmetricKey(mainKey: mainKey, lockedSymmetricKeyData)
        } else if let lockedSymmetricKeyData: Data = try? keychain.get(keyId: keychainKey, isSynced: false) {
            return try unlockSymmetricKey(mainKey: mainKey, lockedSymmetricKeyData)
        } else {
            return try buildSymmetricKey(mainKey: mainKey)
        }
    }

    public func get(keyId: String) throws -> Data {
        let keyData: Data = try keychain.get(keyId: keyId, isSynced: true)
        return keyData
    }

    public func set(_ keyData: Data, for keyId: String) throws {
        try keychain.set(keyData, for: keyId, shouldSync: true)
    }

    public func clear(keyId: String, isSynced: Bool) throws {
        try keychain.delete(keyId: keyId, isSynced: isSynced)
    }
}

private extension KeysManager {
    func migrationSymmetricKeyToUnsync(_ lockedSymmetricKeyData: Data) throws {
        try keychain.delete(keyId: keychainKey, isSynced: true)
        try keychain.set(lockedSymmetricKeyData, for: keychainKey, shouldSync: false)
    }

    func buildSymmetricKey(mainKey: MainKey) throws -> SymmetricKey {
        let randomData = try Data.random()
        let lockedData = try Locked<Data>(clearValue: randomData, with: mainKey)
        try keychain.set(lockedData.encryptedValue, for: keychainKey, shouldSync: false)
        return .init(data: randomData)
    }

    func unlockSymmetricKey(mainKey: MainKey, _ lockedSymmetricKeyData: Data) throws -> SymmetricKey {
        let lockedData = Locked<Data>(encryptedValue: lockedSymmetricKeyData)
        var unlockedData: Data
        do {
            unlockedData = try lockedData.unlock(with: mainKey)
        } catch {
            return try buildSymmetricKey(mainKey: mainKey)
        }
        return .init(data: unlockedData)
    }
}
