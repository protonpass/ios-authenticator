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

public final class CoreKeychain: Keychain, @unchecked Sendable {
    public init() {
        super.init(service: "me.proton.authenticator", accessGroup: AppConstants.keychainGroup)
    }
}

extension CoreKeychain: SettingsProvider {
    private static let LockTimeKey = "AuthAccount.LockTimeKey"

    public var lockTime: AutolockTimeout {
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

public final class KeyManager: KeysProvider {
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
        if let lockedSymmetricKeyData: Data = try? keychain.get(key: keychainKey) {
            let lockedData = Locked<Data>(encryptedValue: lockedSymmetricKeyData)
            let unlockedData = try lockedData.unlock(with: mainKey)
            return .init(data: unlockedData)
        } else {
            let randomData = try Data.random()
            let lockedData = try Locked<Data>(clearValue: randomData, with: mainKey)
            try keychain.set(lockedData.encryptedValue, for: keychainKey)
            return .init(data: randomData)
        }
    }
}
