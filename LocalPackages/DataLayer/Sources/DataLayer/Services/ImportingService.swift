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
import CommonUtilities
import Foundation
import Models

public protocol ImportingServicing: Sendable {
    func importEntries(from destination: TwofaImportDestination) throws -> ImportResult
}

public final class ImportingService: ImportingServicing {
    private let importer: AuthenticatorImporter

    public init(importer: AuthenticatorImporter = AuthenticatorImporter()) {
        self.importer = importer
    }

    public func importEntries(from destination: TwofaImportDestination) throws -> ImportResult {
        let result = switch destination {
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
        case let .lasstpass(contents: contents):
            try parseLastpass(contents)
        case let .protonAuthenticator(contents: contents):
            try parseAuthenticator(contents)
        }

        return result.toImportResult
    }
}

private extension ImportingService {
    func parse2fas(_ content: String, password: String?) throws -> AuthenticatorImportResult {
        guard !content.isEmpty else {
            throw ImportingServiceError.contentIsEmpty
        }
        return try importer.importFrom2fas(contents: content, password: password)
    }

    func parseAuthenticator(_ content: String) throws -> AuthenticatorImportResult {
        guard !content.isEmpty else {
            throw ImportingServiceError.contentIsEmpty
        }
        return try importer.importFromProtonAuthenticator(contents: content)
    }

    func parseLastpass(_ content: String) throws -> AuthenticatorImportResult {
        guard !content.isEmpty else {
            throw ImportingServiceError.contentIsEmpty
        }

        guard content.isValidJSON else {
            throw ImportingServiceError.wrongFormat
        }

        return try importer.importFromLastpassJson(contents: content)
    }

    func parseGoogleQr(_ content: String) throws -> AuthenticatorImportResult {
        guard !content.isEmpty else {
            throw ImportingServiceError.contentIsEmpty
        }

        return try importer.importFromGoogleQr(contents: content)
    }

    func parseEnte(_ content: String) throws -> AuthenticatorImportResult {
        guard !content.isEmpty else {
            throw ImportingServiceError.contentIsEmpty
        }

        return try importer.importFromEnteTxt(contents: content)
    }

    func parseBitwarden(_ content: String) throws -> AuthenticatorImportResult {
        guard !content.isEmpty else {
            throw ImportingServiceError.contentIsEmpty
        }

        if content.isValidJSON {
            return try importer.importFromBitwardenJson(contents: content)
        }

        return try importer.importFromBitwardenCsv(contents: content)
    }

    func parseAegis(_ content: String, password: String?) throws -> AuthenticatorImportResult {
        guard !content.isEmpty else {
            throw ImportingServiceError.contentIsEmpty
        }
        if content.isValidJSON {
            return try importer.importFromAegisJson(contents: content, password: password)
        }

        return try importer.importFromAegisTxt(contents: content)
    }
}
