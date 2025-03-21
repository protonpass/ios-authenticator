//
//
// ImportViewModel.swift
// Proton Authenticator - Created on 20/03/2025.
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
//

import DataLayer
import Factory
import Foundation
import Models
import UniformTypeIdentifiers

// public enum TwofaImportDestination: Sendable, Equatable {
//    case twofas(contents: String, password: String?)
//    case aegis(contents: TwofaImportFileType, password: String?)
//    case bitwarden(contents: TwofaImportFileType)
//    case ente(contents: String)
//    case googleQr(contents: String)
//    case lasstpass(contents: TwofaImportFileType)
//    case protonAuthenticator(contents: String)
//
//    public var autorizedFileExtensions: [UTType] {
//        switch self {
//        case .aegis:
//            [.json, .text, .plainText]
//        case .bitwarden:
//            [.json, .commaSeparatedText]
//        case .lasstpass:
//            [.json]
//        case .ente, .protonAuthenticator, .twofas:
//            [.text, .plainText]
//        default:
//            []
//        }
//    }
// }
//
// public enum TwofaImportFileType: Sendable, Equatable {
//    case json(String)
//    case csv(String)
//    case txt(String)
//    case generic(String)
//
//    public var content: String {
//        switch self {
//        case let .json(value):
//            value
//        case let .csv(value):
//            value
//        case let .txt(value):
//            value
//        case let .generic(value):
//            value
//        }
//    }
// }

@Observable @MainActor
final class ImportViewModel {
    var showImporter: ImportProvenance?
    var password: String?

    private(set) var loading = false
    private(set) var displayPasswordPrompt = false

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.entryDataService)
    private(set) var entryDataService

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.alertService)
    private var alertService

    @ObservationIgnored
    private var currentSelected: ImportProvenance?
    @ObservationIgnored
    private var provenance: TwofaImportDestination?

    init() {
        setUp()
    }

    func importEntries(_ provenance: ImportProvenance) {
        currentSelected = provenance
        showImporter = provenance
    }

    func processImportedFile(_ result: Result<[URL], any Error>) {
        provenance = nil
        switch result {
        case let .success(urls):
            guard let url = urls.first,
                  let type = url.mimeType,
                  let currentSelected,
                  currentSelected.autorizedFileExtensions.contains(type) else { return }
            Task {
                defer { loading = false }
                do {
                    loading = true
                    let fileContent = try String(contentsOf: url, encoding: .utf8)
                    provenance = currentSelected.importDestination(content: fileContent, type: type, password: password)
                    guard let provenance else { return }
                    try await entryDataService.importEntries(from: provenance)
                    // TODO: should dimiss if all good
                } catch ImportException.MissingPassword {
                    displayPasswordPrompt.toggle()
                } catch ImportException.BadPassword {
                    alertService.showError(error, mainDisplay: false, action: { [weak self] in
                        self?.password = ""
                    })
                } catch {
                    alertService.showError(error, mainDisplay: false, action: nil)
                }
            }
        case let .failure(error):
            alertService.showError(error, mainDisplay: false, action: nil)
        }
    }

    func encryptedImport(_ password: String) {
        guard var provenance else {
            return
        }
//    case twofas(contents: String, password: String?)
//    case aegis(contents: TwofaImportFileType, password: String?)
//

        // TODO: try with password
    }
}

private extension ImportViewModel {
    func setUp() {}
}

extension URL {
    var mimeType: UTType? {
        let pathExtension = pathExtension

        return UTType(filenameExtension: pathExtension)
    }
}

enum ImportProvenance: Identifiable, CaseIterable {
    case twofas
    case aegis
    case bitwarden
    case ente
    case googleAuth
    case lasstpass
    case protonAuthenticator

    var autorizedFileExtensions: [UTType] {
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

    var title: String {
        switch self {
        case .aegis:
            "Aegis"
        case .bitwarden:
            "Bitwarden"
        case .ente:
            "Ente"
        case .googleAuth:
            "Google Authenticator"
        case .lasstpass:
            "LastPass"
        case .protonAuthenticator:
            "Proton Authenticator"
        case .twofas:
            "2FA"
        }
    }

    func importDestination(content: String, type: UTType, password: String?) -> TwofaImportDestination {
        switch self {
        case .twofas:
            .twofas(contents: content, password: password)
        case .aegis:
            .aegis(contents: type.toTwofaImportFileType(content: content), password: password)
        case .bitwarden:
            .bitwarden(contents: type.toTwofaImportFileType(content: content))
        case .ente:
            .ente(contents: content)
        case .googleAuth:
            .googleQr(contents: content)
        case .lasstpass:
            .lasstpass(contents: type.toTwofaImportFileType(content: content))
        case .protonAuthenticator:
            .protonAuthenticator(contents: content)
        }
    }

    var id: Self { self }
}

extension UTType {
    func toTwofaImportFileType(content: String) -> TwofaImportFileType {
        switch self {
        case .plainText, .text:
            .txt(content)
        case .json:
            .json(content)
        case .commaSeparatedText:
            .csv(content)
        default:
            .generic(content)
        }
    }
}

//        #expect(throws: AuthenticatorImportException.BadPassword(message: "BadPassword")) {
//            try sut.importEntries(from: .twofas(contents: MockImporterData.encrypted2fas, password: "wrong"))
//        }
//
//        #expect(throws: AuthenticatorImportException.MissingPassword(message: "MissingPassword"))

//    case twofas(contents: String, password: String?)
//    case aegis(contents: TwofaImportFileType, password: String?)
//    case bitwarden(contents: TwofaImportFileType)
//    case ente(contents: String)
//    case googleQr(contents: String)
//    case lasstpass(contents: TwofaImportFileType)
//    case protonAuthenticator(contents: String)

//
// enum importType {
//
//
//
//    var autorizedType: UTType {
//
//
//    }
// }

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
//    func parseLastpass(_ content: String) throws -> AuthenticatorImportResult {
//        guard !content.isEmpty else {
//            throw AuthError.importing(.contentIsEmpty)
//        }
//
//        guard content.isValidJSON else {
//            throw AuthError.importing(.wrongFormat)
//        }
//
//        return try importer.importFromLastpassJson(contents: content)
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
//    func parseBitwarden(_ content: String) throws -> AuthenticatorImportResult {
//        guard !content.isEmpty else {
//            throw AuthError.importing(.contentIsEmpty)
//        }
//
//        if content.isValidJSON {
//            return try importer.importFromBitwardenJson(contents: content)
//        }
//
//        return try importer.importFromBitwardenCsv(contents: content)
//    }
//
//    func parseAegis(_ content: String, password: String?) throws -> AuthenticatorImportResult {
//        guard !content.isEmpty else {
//            throw AuthError.importing(.contentIsEmpty)
//        }
//        if content.isValidJSON {
//            return try importer.importFromAegisJson(contents: content, password: password)
//        }
//
//        return try importer.importFromAegisTxt(contents: content)
//    }
// }
