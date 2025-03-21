//
// TwofaImportDestination.swift
// Proton Authenticator - Created on 27/02/2025.
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
import UniformTypeIdentifiers

public enum TwofaImportDestination: Sendable, Equatable {
    case twofas(contents: String, password: String?)
    case aegis(contents: TwofaImportFileType, password: String?)
    case bitwarden(contents: TwofaImportFileType)
    case ente(contents: String)
    case googleQr(contents: String)
    case lasstpass(contents: TwofaImportFileType)
    case protonAuthenticator(contents: String)

    public var autorizedFileExtensions: [UTType] {
        switch self {
        case .aegis:
            [.json, .text, .plainText]
        case .bitwarden:
            [.json, .commaSeparatedText]
        case .lasstpass:
            [.json]
        case .ente, .protonAuthenticator, .twofas:
            [.text, .plainText]
        default:
            []
        }
    }
}

public enum TwofaImportFileType: Sendable, Equatable {
    case json(String)
    case csv(String)
    case txt(String)
    case generic(String)

    public var content: String {
        switch self {
        case let .json(value):
            value
        case let .csv(value):
            value
        case let .txt(value):
            value
        case let .generic(value):
            value
        }
    }
}

//
// public protocol ImportingServicing: Sendable {
//    func importEntries(from destination: TwofaImportDestination) throws -> ImportResult
// }
//
// public final class ImportingService: ImportingServicing {
//    private let importer: AuthenticatorImporter
//
//    public init(importer: AuthenticatorImporter = AuthenticatorImporter()) {
//        self.importer = importer
//    }
//
//    public func importEntries(from destination: TwofaImportDestination) throws -> ImportResult {
//        let result = switch destination {
//        case let .twofas(contents: contents, password: password):
//            try parse2fas(contents, password: password)
//        case let .aegis(contents: contents, password: password):
//            try parseAegis(contents, password: password)
//        case let .bitwarden(contents: contents):
//            try parseBitwarden(contents)
//        case let .ente(contents: contents):
//            try parseEnte(contents)
//        case let .googleQr(contents: contents):
//            try parseGoogleQr(contents)
//        case let .lasstpass(contents: contents):
//            try parseLastpass(contents)
//        case let .protonAuthenticator(contents: contents):
//            try parseAuthenticator(contents)
//        }
//
//        return result.toImportResult
//    }
// }
//
// private extension ImportingService {
//    func parse2fas(_ content: String, password: String?) throws -> AuthenticatorImportResult {
//        guard !content.isEmpty else {
//            throw AuthError.importing(.contentIsEmpty)
//        }
//        return try importer.importFrom2fas(contents: content, password: password)
//    }
//
//    func parseAuthenticator(_ content: String) throws -> AuthenticatorImportResult {
//        guard !content.isEmpty else {
//            throw AuthError.importing(.contentIsEmpty)
//        }
//        return try importer.importFromProtonAuthenticator(contents: content)
//    }
//
//    func parseLastpass(_ content: TwofaImportType) throws -> AuthenticatorImportResult {
//        guard !content.content.isEmpty else {
//            throw AuthError.importing(.contentIsEmpty)
//        }
//
//        if case .json = content {
//            return try importer.importFromLastpassJson(contents: content.content)
//        }
//
//        throw AuthError.importing(.wrongFormat)
//    }
//
//    func parseGoogleQr(_ content: String) throws -> AuthenticatorImportResult {
//        guard !content.isEmpty else {
//            throw AuthError.importing(.contentIsEmpty)
//        }
//
//        return try importer.importFromGoogleQr(contents: content)
//    }
//
//    func parseEnte(_ content: String) throws -> AuthenticatorImportResult {
//        guard !content.isEmpty else {
//            throw AuthError.importing(.contentIsEmpty)
//        }
//
//        return try importer.importFromEnteTxt(contents: content)
//    }
//
//    func parseBitwarden(_ content: TwofaImportType) throws -> AuthenticatorImportResult {
//        guard !content.content.isEmpty else {
//            throw AuthError.importing(.contentIsEmpty)
//        }
//
//        if case .json = content {
//            return try importer.importFromBitwardenJson(contents: content.content)
//        } else if case .csv = content {
//            return try importer.importFromBitwardenCsv(contents: content.content)
//        }
//        throw AuthError.importing(.wrongFormat)
//    }
//
//    func parseAegis(_ content: TwofaImportType, password: String?) throws -> AuthenticatorImportResult {
//        guard !content.content.isEmpty else {
//            throw AuthError.importing(.contentIsEmpty)
//        }
//
//        if case .json = content {
//            return try importer.importFromAegisJson(contents: content.content, password: password)
//        } else if case .txt = content {
//            return try  importer.importFromAegisTxt(contents: content.content)
//        }
//
//        throw AuthError.importing(.wrongFormat)
//    }
// }
