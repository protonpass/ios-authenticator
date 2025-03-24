//
// AuthenticationService.swift
// Proton Authenticator - Created on 23/03/2025.
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

import Combine
import CommonUtilities
import Foundation
import LocalAuthentication
import Models

@MainActor
public protocol AuthenticationServicing: Sendable, Observable {
    var biometricEnabled: Bool { get }
    var biometricChecked: Bool { get }

    func setBiometricEnabled(_ enabled: Bool) throws
    func checkBiometrics()
    func resetBiometricChecked()
}

@MainActor
@Observable
public final class AuthenticationService: AuthenticationServicing {
    @ObservationIgnored
    private let keychain: any KeychainServicing

    public private(set) var biometricEnabled: Bool = false
    public private(set) var biometricChecked: Bool = false

    public init(keychain: any KeychainServicing = SimpleKeychain(service: AppConstants.service,
                                                                 accessGroup: AppConstants.keychainGroup)) {
        self.keychain = keychain
        do {
            biometricEnabled = try keychain.get(key: AppConstants.Settings.faceIdEnabled)
        } catch {}
    }

    public func setBiometricEnabled(_ enabled: Bool) throws {
        try keychain.set(enabled, for: AppConstants.Settings.faceIdEnabled)
        biometricEnabled = enabled
        biometricChecked = enabled
    }

    public func resetBiometricChecked() {
        biometricChecked = false
    }

    public func checkBiometrics() {
        Task {
            let context = LAContext()
            var error: NSError?

            if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
                let reason = "Identify yourself!"
                do {
                    biometricChecked = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                                                                        localizedReason: reason)
                } catch {
                    print(error.localizedDescription)
                }
            } else {
                print(error?.localizedDescription)
            }
        }
    }
}

// @objc func requestBiometricPermission() {
//    let context = LAContext()
//    var error: NSError?
//
//    if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
//        let reason = "Identify yourself!"
//
//        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, _ in
//
//            DispatchQueue.main.async {
//                if success {
//                    let crumb = Breadcrumb()
//                    crumb.message = "Biometry success"
//                    SentrySDK.addBreadcrumb(crumb)
//                } else {
//                    let crumb = Breadcrumb()
//                    crumb.message = "Biometry failure"
//                    SentrySDK.addBreadcrumb(crumb)
//                }
//            }
//        }
//    } else {
//        let ac = UIAlertController(title: "No biometry", message: "Couldn't access biometry.", preferredStyle:
//        .alert)
//        ac.addAction(UIAlertAction(title: "OK", style: .default))
//        self.present(ac, animated: true)
//    }
// }

public protocol KeychainServicing: Sendable {
    @discardableResult
    func get<T: Decodable & Sendable>(key: String, ofType itemClassType: ItemClassType) throws -> T
    func set<T: Encodable & Sendable>(_ item: T,
                                      for key: String,
                                      ofType itemClassType: ItemClassType,
                                      with access: KeychainAccessOptions,
                                      attributes: [CFString: any Sendable]?) throws
    func delete(_ key: String, ofType itemClassType: ItemClassType) throws
    func clear(ofType itemClassType: ItemClassType) throws
}

extension KeychainServicing {
    @discardableResult
    func get<T: Decodable & Sendable>(key: String, ofType itemClassType: ItemClassType = .generic) throws -> T {
        try get(key: key, ofType: itemClassType)
    }

    func set(_ item: some Encodable & Sendable,
             for key: String,
             ofType itemClassType: ItemClassType = .generic,
             with access: KeychainAccessOptions = .default,
             attributes: [CFString: any Sendable]? = nil) throws {
        try set(item, for: key, ofType: itemClassType, with: access, attributes: attributes)
    }

    func delete(_ key: String, ofType itemClassType: ItemClassType = .generic) throws {
        try delete(key, ofType: itemClassType)
    }

    func clear(ofType itemClassType: ItemClassType = .generic) throws {
        try clear(ofType: itemClassType)
    }
}

public final class SimpleKeychain: KeychainServicing {
    private let service: String?
    private let accessGroup: String?

    public init(service: String? = nil, accessGroup: String? = nil) {
        self.service = service
        self.accessGroup = accessGroup
    }

    @discardableResult
    public func get<T: Decodable & Sendable>(key: String,
                                             ofType itemClassType: ItemClassType = .generic) throws -> T {
        var query = createQuery(for: key, ofType: itemClassType)
        query[kSecMatchLimit] = kSecMatchLimitOne
        query[kSecReturnAttributes] = kCFBooleanTrue
        query[kSecReturnData] = kCFBooleanTrue

        var item: CFTypeRef?
        let result = SecItemCopyMatching(query as CFDictionary, &item)
        if result != errSecSuccess {
            throw result.toSimpleKeychainError
        }

        guard let keychainItem = item as? [CFString: Any],
              let data = keychainItem[kSecValueData] as? Data else {
            throw SimpleKeychainError.invalidData
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    public func set(_ item: some Encodable & Sendable,
                    for key: String,
                    ofType itemClassType: ItemClassType = .generic,
                    with access: KeychainAccessOptions = .default,
                    attributes: [CFString: any Sendable]? = nil) throws {
        let data = try JSONEncoder().encode(item)

        do {
            try add(with: data, key: key, ofType: itemClassType, with: access, attributes: attributes)
        } catch SimpleKeychainError.duplicateItem {
            try update(with: data, key: key, ofType: itemClassType, with: access, attributes: attributes)
        }
    }

    public func delete(_ key: String, ofType itemClassType: ItemClassType = .generic) throws {
        let query = createQuery(for: key, ofType: itemClassType)
        let result = SecItemDelete(query as CFDictionary)
        if result != errSecSuccess {
            let error = result.toSimpleKeychainError
            switch error {
            case .itemNotFound:
                break
            default:
                throw error
            }
        }
    }

    public func clear(ofType itemClassType: ItemClassType = .generic) throws {
        var query: [CFString: Any] = [kSecClass: itemClassType.rawValue]
        if let accessGroup {
            query[kSecAttrAccessGroup] = accessGroup
        }

        let result = SecItemDelete(query as CFDictionary)
        if result != errSecSuccess {
            throw result.toSimpleKeychainError
        }
    }
}

private extension SimpleKeychain {
    func update(with data: Data,
                key: String,
                ofType itemClassType: ItemClassType,
                with access: KeychainAccessOptions,
                attributes: [CFString: Any]? = nil) throws {
        let query = createQuery(for: key, ofType: itemClassType, access: access, attributes: attributes)
        let updates: [CFString: Any] = [
            kSecValueData: data
        ]

        let result = SecItemUpdate(query as CFDictionary, updates as CFDictionary)
        if result != errSecSuccess {
            throw result.toSimpleKeychainError
        }
    }

    func add(with data: Data,
             key: String,
             ofType itemClassType: ItemClassType,
             with access: KeychainAccessOptions,
             attributes: [CFString: Any]? = nil) throws {
        let query = createQuery(for: key, ofType: itemClassType, with: data, access: access,
                                attributes: attributes)

        let result = SecItemAdd(query as CFDictionary, nil)
        if result != errSecSuccess {
            throw result.toSimpleKeychainError
        }
    }

    func createQuery(for key: String,
                     ofType itemClassType: ItemClassType,
                     with data: Data? = nil,
                     access: KeychainAccessOptions = .default,
                     attributes: [CFString: Any]? = nil) -> [CFString: Any] {
        var query: [CFString: Any] = [:]
        query[kSecClass] = itemClassType.rawValue
        query[kSecAttrAccount] = key
        query[kSecAttrAccessible] = access.value
        query[kSecUseDataProtectionKeychain] = kCFBooleanTrue

        if let data {
            query[kSecValueData] = data
        }

        if let service {
            query[kSecAttrService] = service
        }

        if let accessGroup {
            query[kSecAttrAccessGroup] = accessGroup
        }

        if let attributes {
            for (key, value) in attributes {
                query[key] = value
            }
        }

        return query
    }
}

public enum ItemClassType: RawRepresentable, Sendable {
    public typealias RawValue = CFString

    case generic
    case password
    case certificate
    case cryptography
    case identity

    public init?(rawValue: CFString) {
        switch rawValue {
        case kSecClassGenericPassword:
            self = .generic
        case kSecClassInternetPassword:
            self = .password
        case kSecClassCertificate:
            self = .certificate
        case kSecClassKey:
            self = .cryptography
        case kSecClassIdentity:
            self = .identity
        default:
            return nil
        }
    }

    public var rawValue: CFString {
        switch self {
        case .generic:
            kSecClassGenericPassword
        case .password:
            kSecClassInternetPassword
        case .certificate:
            kSecClassCertificate
        case .cryptography:
            kSecClassKey
        case .identity:
            kSecClassIdentity
        }
    }
}

/**

 These options are used to determine when a keychain item should be readable. The default value is AccessibleWhenUnlocked.

 */
public enum KeychainAccessOptions: Sendable {
    /**

     The data in the keychain item can be accessed only while the device is unlocked by the user.

     This is recommended for items that need to be accessible only while the application is in the foreground. Items with this attribute migrate to a new device when using encrypted backups.

     This is the default value for keychain items added without explicitly setting an accessibility constant.

     */
    case accessibleWhenUnlocked

    /**

     The data in the keychain item can be accessed only while the device is unlocked by the user.

     This is recommended for items that need to be accessible only while the application is in the foreground. Items with this attribute do not migrate to a new device. Thus, after restoring from a backup of a different device, these items will not be present.

     */
    case accessibleWhenUnlockedThisDeviceOnly

    /**

     The data in the keychain item cannot be accessed after a restart until the device has been unlocked once by the user.

     After the first unlock, the data remains accessible until the next restart. This is recommended for items that need to be accessed by background applications. Items with this attribute migrate to a new device when using encrypted backups.

     */
    case accessibleAfterFirstUnlock

    /**

     The data in the keychain item cannot be accessed after a restart until the device has been unlocked once by the user.

     After the first unlock, the data remains accessible until the next restart. This is recommended for items that need to be accessed by background applications. Items with this attribute do not migrate to a new device. Thus, after restoring from a backup of a different device, these items will not be present.

     */
    case accessibleAfterFirstUnlockThisDeviceOnly

    /**

     The data in the keychain can only be accessed when the device is unlocked. Only available if a passcode is set on the device.

     This is recommended for items that only need to be accessible while the application is in the foreground. Items with this attribute never migrate to a new device. After a backup is restored to a new device, these items are missing. No items can be stored in this class on devices without a passcode. Disabling the device passcode causes all items in this class to be deleted.

     */
    case accessibleWhenPasscodeSetThisDeviceOnly

    public static var `default`: KeychainAccessOptions {
        .accessibleWhenUnlocked
    }

    var value: String {
        switch self {
        case .accessibleWhenUnlocked:
            kSecAttrAccessibleWhenUnlocked.toString

        case .accessibleWhenUnlockedThisDeviceOnly:
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly.toString

        case .accessibleAfterFirstUnlock:
            kSecAttrAccessibleAfterFirstUnlock.toString

        case .accessibleAfterFirstUnlockThisDeviceOnly:
            kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly.toString

        case .accessibleWhenPasscodeSetThisDeviceOnly:
            kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly.toString
        }
    }
}

public enum SimpleKeychainError: Error, Equatable {
    case invalidData
    case itemNotFound
    case duplicateItem
    case incorrectAttributeForClass
    case unexpected(OSStatus)

    var localizedDescription: String {
        switch self {
        case .invalidData:
            "Invalid data"
        case .itemNotFound:
            "Item not found"
        case .duplicateItem:
            "Duplicate Item"
        case .incorrectAttributeForClass:
            "Incorrect Attribute for Class"
        case let .unexpected(oSStatus):
            "Unexpected error - \(oSStatus)"
        }
    }
}

extension OSStatus {
    var toSimpleKeychainError: SimpleKeychainError {
        switch self {
        case errSecItemNotFound:
            .itemNotFound
        case errSecDataTooLarge:
            .invalidData
        case errSecDuplicateItem:
            .duplicateItem
        default:
            .unexpected(self)
        }
    }
}

extension CFString {
    var toString: String {
        self as String
    }
}
