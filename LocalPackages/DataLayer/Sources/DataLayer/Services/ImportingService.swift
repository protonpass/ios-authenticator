//
// ImportingService.swift
// Proton Authenticator - Created on 11/02/2025.
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

public typealias ImportException = AuthenticatorImportException

public protocol ImportingServicing: Sendable {
    func importEntries(from provenance: TwofaImportSource) throws -> ImportResult
}

public final class ImportingService: ImportingServicing {
    private let importer: any AuthenticatorImporterProtocol
    private let logger: LoggerProtocol

    public init(importer: any AuthenticatorImporterProtocol = AuthenticatorImporter(),
                logger: any LoggerProtocol) {
        self.importer = importer
        self.logger = logger
    }

    public func importEntries(from provenance: TwofaImportSource) throws -> ImportResult {
        log(.debug, "Starting import from provenance: \(provenance)")
        let result = switch provenance {
        case let .twofas(contents: contents, password: password):
            try parse2fas(contents, password: password)
        case let .aegis(contents: contents, password: password):
            try parseAegis(contents, password: password)
        case let .bitwarden(contents: contents):
            try parseBitwarden(contents)
        case let .ente(contents: contents):
            try parseEnte(contents)
        case let .googleQr(contents: contents):
            try parseGoogleQr(contents)
        case let .lastpass(contents: contents):
            try parseLastpass(contents)
        case let .protonAuthenticator(contents: contents):
            try parseAuthenticator(contents)
        }

        log(.debug, "Successfully parsed entries from provenance: \(provenance)")
        return result.toImportResult
    }
}

private extension ImportingService {
    func parse2fas(_ content: String, password: String?) throws -> AuthenticatorImportResult {
        log(.debug, "Parsing 2fas content")
        guard !content.isEmpty else {
            log(.warning, "2fas content is empty")
            throw AuthError.importing(.contentIsEmpty)
        }
        return try importer.importFrom2fas(contents: content, password: password)
    }

    func parseAuthenticator(_ content: String) throws -> AuthenticatorImportResult {
        log(.debug, "Parsing Proton Authenticator content")
        guard !content.isEmpty else {
            log(.warning, "Proton Authenticator content is empty")
            throw AuthError.importing(.contentIsEmpty)
        }
        return try importer.importFromProtonAuthenticator(contents: content)
    }

    func parseLastpass(_ content: TwofaImportFileType) throws -> AuthenticatorImportResult {
        log(.debug, "Parsing LastPass content")
        guard !content.content.isEmpty else {
            log(.warning, "LastPass content is empty")
            throw AuthError.importing(.contentIsEmpty)
        }

        if case .json = content {
            return try importer.importFromLastpassJson(contents: content.content)
        }
        log(.error, "LastPass content is in wrong format")
        throw AuthError.importing(.wrongFormat)
    }

    func parseGoogleQr(_ content: String) throws -> AuthenticatorImportResult {
        log(.debug, "Parsing Google QR content")
        guard !content.isEmpty else {
            log(.warning, "Google QR content is empty")
            throw AuthError.importing(.contentIsEmpty)
        }

        return try importer.importFromGoogleQr(contents: content)
    }

    func parseEnte(_ content: String) throws -> AuthenticatorImportResult {
        log(.debug, "Parsing Ente content")
        guard !content.isEmpty else {
            log(.warning, "Ente content is empty")
            throw AuthError.importing(.contentIsEmpty)
        }

        return try importer.importFromEnteTxt(contents: content)
    }

    func parseBitwarden(_ content: TwofaImportFileType) throws -> AuthenticatorImportResult {
        log(.debug, "Parsing Bitwarden content")
        guard !content.content.isEmpty else {
            log(.warning, "Bitwarden content is empty")
            throw AuthError.importing(.contentIsEmpty)
        }

        if case .json = content {
            return try importer.importFromBitwardenJson(contents: content.content)
        } else if case .csv = content {
            return try importer.importFromBitwardenCsv(contents: content.content)
        }
        log(.error, "Bitwarden content is in wrong format")
        throw AuthError.importing(.wrongFormat)
    }

    func parseAegis(_ content: TwofaImportFileType, password: String?) throws -> AuthenticatorImportResult {
        log(.debug, "Parsing Aegis content")
        guard !content.content.isEmpty else {
            log(.warning, "Aegis content is empty")
            throw AuthError.importing(.contentIsEmpty)
        }

        if case .json = content {
            return try importer.importFromAegisJson(contents: content.content, password: password)
        } else if case .txt = content {
            return try importer.importFromAegisTxt(contents: content.content)
        }

        log(.error, "Aegis content is in wrong format")
        throw AuthError.importing(.wrongFormat)
    }

    func log(_ level: LogLevel, _ message: String, function: String = #function, line: Int = #line) {
        logger.log(level, category: .data, message, function: function, line: line)
    }
}
