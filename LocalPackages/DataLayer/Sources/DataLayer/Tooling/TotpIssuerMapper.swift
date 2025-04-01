//
// TotpIssuerMapper.swift
// Proton Authenticator - Created on 26/03/2025.
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

import AuthenticatorRustCore
import Foundation
import Models
#if canImport(UIKit)
import UIKit
#endif

// open class AuthenticatorIssuerMapper : AuthenticatorRustCore.AuthenticatorIssuerMapperProtocol, @unchecked
// Sendable {
//
//    /// Used to instantiate a [FFIObject] without an actual pointer, for fakes in tests, mostly.
//    public struct NoPointer {
//
//        public init()
//    }
//
//    required public init(unsafeFromRawPointer pointer: UnsafeMutableRawPointer)
//
//    public init(noPointer: AuthenticatorRustCore.AuthenticatorIssuerMapper.NoPointer)
//
//    public func uniffiClonePointer() -> UnsafeMutableRawPointer
//
//    public convenience init()
//
//    open func getImage(path: String) -> Data?
//
//    open func lookup(issuer: String) -> AuthenticatorRustCore.IssuerInfo?
// }
//
// public protocol AuthenticatorIssuerMapperProtocol :
//
public protocol TOTPIssuerMapperServicing: Sendable {
    func lookup(issuer: String) -> AuthIssuerInfo?
    func getIcon(path: String) -> Data?
}

/// A library to map TOTP issuer names to domains and icons
public final class TOTPIssuerMapper: TOTPIssuerMapperServicing {
    //    private let issuerInfos: [String: IssuerInfo]
    private let mapper: any AuthenticatorIssuerMapperProtocol

    public init(mapper: any AuthenticatorIssuerMapperProtocol = AuthenticatorIssuerMapper()) {
        //        let domains = Self.loadDomains()
        //        issuerInfos = Self.getIssuerInfo(domainList: domains)
        self.mapper = mapper
        print("woot mapper available  path : \(mapper.listAvailableImages())")
    }

    /// Look up an issuer and return its domain and icon information
    /// - Parameter issuer: The issuer name from the TOTP
    /// - Returns: IssuerInfo containing the domain and icon name if available
    public func lookup(issuer: String) -> AuthIssuerInfo? {
        mapper.lookup(issuer: issuer)?.toAuthIssuerInfo
    }

    public func getIcon(path: String) -> Data? {
        mapper.getImage(path: path)
    }
}

extension IssuerInfo {
    var toAuthIssuerInfo: AuthIssuerInfo {
        AuthIssuerInfo(domain: domain,
                       iconName: iconName,
                       iconPath: issuerIconPath,
                       bundleId: Bundle.module.bundleIdentifier)
    }
}

// ublic struct IssuerInfo {
//    public var domain: String
//    public var iconName: String?
//    public var issuerIconPath: String?
//
//// MARK: - Icon Management
//
// private extension TOTPIssuerMapper {
//    /// Normalize an issuer name by removing special characters and converting to lowercase
//    /// - Parameter issuer: The raw issuer name
//    /// - Returns: Normalized issuer name
//    func normalizeIssuer(_ issuer: String) -> String {
//        // Remove spaces, special characters, and convert to lowercase
//        let normalized = issuer.lowercased()
//            .replacingOccurrences(of: " ", with: "")
//            .replacingOccurrences(of: ".", with: "")
//            .replacingOccurrences(of: ",", with: "")
//            .replacingOccurrences(of: "-", with: "")
//            .replacingOccurrences(of: "_", with: "")
//
//        return normalized
//    }
//
//    /// Attempt fuzzy matching for issuers that don't have a direct match
//    /// - Parameter normalized: The normalized issuer name
//    /// - Returns: IssuerInfo if a match is found
//    func fuzzyLookup(normalized: String) -> IssuerInfo? {
//        // Check if issuer contains or is contained within a key
//        for (key, domainInfos) in issuerInfos {
//            if (key.count >= 3 && normalized.contains(key)) || key.contains(normalized) {
//                return domainInfos
//            }
//        }
//
//        // Check for partial matches (e.g., "gitlb" matching "gitlab")
//        if normalized.count > 3 {
//            for (key, domainInfo) in issuerInfos where key.count > 3 {
//                // Calculate Levenshtein distance for keys of similar length
//                if abs(key.count - normalized.count) <= 2 {
//                    let distance = levenshteinDistance(normalized, key)
//                    // Accept matches with small distance relative to length
//                    if distance <= min(key.count, normalized.count) / 3 {
//                        return domainInfo
//                    }
//                }
//            }
//        }
//
//        return nil
//    }
//
//    /// Calculate Levenshtein distance between two strings
//    /// - Parameters:
//    ///   - s1: First string
//    ///   - s2: Second string
//    /// - Returns: Levenshtein distance
//    func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
//        let firstString = Array(s1)
//        let firstStringSize = firstString.count
//
//        let secondString = Array(s2)
//        let secondStringSize = secondString.count
//
//        var dist = Array(repeating: Array(repeating: 0, count: secondStringSize + 1), count: firstStringSize + 1)
//
//        for index in 0...firstStringSize {
//            dist[index][0] = index
//        }
//
//        for index in 0...secondStringSize {
//            dist[0][index] = index
//        }
//
//        for indexFirstString in 1...firstStringSize {
//            for indexSecondString in 1...secondStringSize {
//                if firstString[indexFirstString - 1] == secondString[indexSecondString - 1] {
//                    dist[indexFirstString][indexSecondString] = dist[indexFirstString - 1][indexSecondString - 1]
//                } else {
//                    dist[indexFirstString][indexSecondString] =
//                        min(dist[indexFirstString - 1][indexSecondString] + 1,
//                            dist[indexFirstString][indexSecondString - 1] +
//                                1,
//                            dist[indexFirstString - 1][
//                                indexSecondString -
//                                    1
//                            ] + 1)
//                }
//            }
//        }
//
//        return dist[firstStringSize][secondStringSize]
//    }
// }
//
//// MARK: - Static init  tools
//
// private extension TOTPIssuerMapper {
//    static func loadDomains() -> [String] {
//        let domainsListFilename = "2faDomains"
//        guard let path = Bundle.module.path(forResource: domainsListFilename, ofType: "txt"),
//              let data = try? String(contentsOfFile: path, encoding: .utf8) else {
//            return []
//        }
//        return data.components(separatedBy: .newlines).filter { !$0.isEmpty }
//    }
//
//    static func getIssuerInfo(domainList: [String]) -> [String: IssuerInfo] {
//        var map: [String: IssuerInfo] = [:]
//
//        // Create mappings from domain parts to the full domain
//        for domain in domainList {
//            var iconName: String?
//
//            #if os(iOS)
//            if UIImage(named: domain, in: Bundle.module, with: nil) != nil {
//                iconName = domain
//            }
//            #elseif os(macOS)
//            if Bundle.module.image(forResource: domain) != nil {
//                iconName = domain
//            }
//            #endif
//
//            // Extract parts before TLD
//            let components = domain.split(separator: ".")
//            if components.isEmpty { continue }
//
//            // Use the main domain name as the key (e.g., "github" for "github.com")
//            let mainName = String(components[0]).lowercased()
//            map[mainName] = IssuerInfo(domain: domain,
//                                       iconName: iconName,
//                                       bundleId: Bundle.module.bundleIdentifier)
//
//            // Handle domains with hyphens (e.g., "square-enix" from "square-enix-games.com")
//            if mainName.contains("-") {
//                let parts = mainName.split(separator: "-")
//                // Map first part (e.g., "square" from "square-enix")
//                map[String(parts[0])] = IssuerInfo(domain: domain,
//                                                   iconName: iconName,
//                                                   bundleId: Bundle.module.bundleIdentifier)
//
//                // Handle cases like "square-enix" where both parts might be used as issuer
//                if parts.count > 1 {
//                    let combined = parts.joined()
//                    map[combined] = IssuerInfo(domain: domain,
//                                               iconName: iconName,
//                                               bundleId: Bundle.module.bundleIdentifier)
//                }
//            }
//        }
//
//        return map
//    }
// }
