//
// CryptoFailureReason.swift
// Proton Authenticator - Created on 13/05/2025.
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

public enum CryptoFailureReason: CustomDebugStringConvertible, Sendable {
    case failedToSplitPGPMessage
    case failedToUnarmor(String)
    case failedToArmor(String)
    case failedToBase64Decode
    case failedToGetFingerprint
    case failedToGenerateKeyRing
    case failedToEncrypt
    case failedToVerifyVault
    case failedToDecryptContent
    case failedToVerifySignature
    case failedToGenerateSessionKey
    case failedToDecode
    case failedToEncode(String)
    case failedToAESEncrypt
    case inactiveUserKey(userKeyId: String) // Caused by "forgot password"
    case addressNotFound(addressID: String)
    case missingUserKey(userID: String)
    case missingPassphrase(keyID: String)
    case missingKeys
    case unmatchedKeyRotation(lhsKey: Int64, rhsKey: Int64)
    case corruptedContent(String)
    case missingRemoteEncryptionKey

    public var debugDescription: String {
        switch self {
        case .failedToSplitPGPMessage:
            String(localized: "Failed to split PGP message", bundle: .module)
        case let .failedToUnarmor(string):
            String(localized: "Failed to unarmor \(string)", bundle: .module)
        case let .failedToArmor(string):
            String(localized: "Failed to armor \(string)", bundle: .module)
        case .failedToBase64Decode:
            String(localized: "Failed to base 64 decode", bundle: .module)
        case .failedToGetFingerprint:
            String(localized: "Failed to get fingerprint", bundle: .module)
        case .failedToGenerateKeyRing:
            String(localized: "Failed to generate key ring", bundle: .module)
        case .failedToEncrypt:
            String(localized: "Failed to encrypt", bundle: .module)
        case .failedToVerifyVault:
            String(localized: "Failed to verify vault", bundle: .module)
        case .failedToDecryptContent:
            String(localized: "Failed to decrypt content", bundle: .module)
        case .failedToVerifySignature:
            String(localized: "Failed to verify signature", bundle: .module)
        case .failedToGenerateSessionKey:
            String(localized: "Failed to generate session key", bundle: .module)
        case .failedToDecode:
            String(localized: "Failed to decode", bundle: .module)
        case let .failedToEncode(string):
            String(localized: "Failed to encode \"\(string)\"", bundle: .module)
        case .failedToAESEncrypt:
            String(localized: "Failed to AES encrypt", bundle: .module)
        case let .inactiveUserKey(userKeyId):
            String(localized: "Inactive user key \(userKeyId)", bundle: .module)
        case let .addressNotFound(addressID):
            String(localized: "Address not found \"\(addressID)\"", bundle: .module)
        case let .corruptedContent(contentID):
            String(localized: "Corrupted content id \"\(contentID)\"", bundle: .module)
        case let .missingUserKey(userID):
            String(localized: "Missing user key \"\(userID)\"", bundle: .module)
        case let .missingPassphrase(keyID):
            String(localized: "Missing passphrase \"\(keyID)\"", bundle: .module)
        case .missingKeys:
            String(localized: "Missing keys", bundle: .module)
        case let .unmatchedKeyRotation(lhsKey, rhsKey):
            String(localized: "Unmatch key rotation \(lhsKey) - \(rhsKey)", bundle: .module)
        case .missingRemoteEncryptionKey:
            String(localized: "Missing remote encryption key", bundle: .module)
        }
    }

//    public var debugDescription: String {
//        switch self {
//        case .failedToSplitPGPMessage:
//            "Failed to split PGP message"
//        case let .failedToUnarmor(string):
//            "Failed to unarmor \(string)"
//        case let .failedToArmor(string):
//            "Failed to armor \(string)"
//        case .failedToBase64Decode:
//            "Failed to base 64 decode"
//        case .failedToGetFingerprint:
//            "Failed to get fingerprint"
//        case .failedToGenerateKeyRing:
//            "Failed to generate key ring"
//        case .failedToEncrypt:
//            "Failed to encrypt"
//        case .failedToVerifyVault:
//            "Failed to verify vault"
//        case .failedToDecryptContent:
//            "Failed to decrypt content"
//        case .failedToVerifySignature:
//            "Failed to verify signature"
//        case .failedToGenerateSessionKey:
//            "Failed to generate session key"
//        case .failedToDecode:
//            "Failed to decode"
//        case let .failedToEncode(string):
//            "Failed to encode \"\(string)\""
//        case .failedToAESEncrypt:
//            "Failed to AES encrypt"
//        case let .inactiveUserKey(userKeyId):
//            "Inactive user key \(userKeyId)"
//        case let .addressNotFound(addressID):
//            "Address not found \"\(addressID)\""
//        case let .corruptedContent(contentID):
//            "Corrupted content id \"\(contentID)\""
//        case let .missingUserKey(userID):
//            "Missing user key \"\(userID)\""
//        case let .missingPassphrase(keyID):
//            "Missing passphrase \"\(keyID)\""
//        case .missingKeys:
//            "Missing keys"
//        case let .unmatchedKeyRotation(lhsKey, rhsKey):
//            "Unmatch key rotation \(lhsKey) - \(rhsKey)"
//        case .missingRemoteEncryptionKey:
//            "Missing remote encryption key"
//        }
//    }
}
