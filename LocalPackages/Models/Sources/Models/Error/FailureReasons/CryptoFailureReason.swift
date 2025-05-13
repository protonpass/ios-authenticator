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

    public var debugDescription: String {
        switch self {
        case .failedToSplitPGPMessage:
            "Failed to split PGP message"
        case let .failedToUnarmor(string):
            "Failed to unarmor \(string)"
        case let .failedToArmor(string):
            "Failed to armor \(string)"
        case .failedToBase64Decode:
            "Failed to base 64 decode"
        case .failedToGetFingerprint:
            "Failed to get fingerprint"
        case .failedToGenerateKeyRing:
            "Failed to generate key ring"
        case .failedToEncrypt:
            "Failed to encrypt"
        case .failedToVerifyVault:
            "Failed to verify vault"
        case .failedToDecryptContent:
            "Failed to decrypt content"
        case .failedToVerifySignature:
            "Failed to verify signature"
        case .failedToGenerateSessionKey:
            "Failed to generate session key"
        case .failedToDecode:
            "Failed to decode"
        case let .failedToEncode(string):
            "Failed to encode \"\(string)\""
        case .failedToAESEncrypt:
            "Failed to AES encrypt"
        case let .inactiveUserKey(userKeyId):
            "Inactive user key \(userKeyId)"
        case let .addressNotFound(addressID):
            "Address not found \"\(addressID)\""
        case let .corruptedContent(contentID):
            "Corrupted content id \"\(contentID)\""
        case let .missingUserKey(userID):
            "Missing user key \"\(userID)\""
        case let .missingPassphrase(keyID):
            "Missing passphrase \"\(keyID)\""
        case .missingKeys:
            "Missing keys"
        case let .unmatchedKeyRotation(lhsKey, rhsKey):
            "Unmatch key rotation \(lhsKey) - \(rhsKey)"
        }
    }
}
