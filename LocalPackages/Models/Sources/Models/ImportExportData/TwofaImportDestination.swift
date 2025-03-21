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

    public func updatePassword(_ password: String?) -> Self {
        switch self {
        case .twofas(contents: let contents, password: _):
            .twofas(contents: contents, password: password)
        case .aegis(contents: let contents, password: _):
            .aegis(contents: contents, password: password)
        default:
            self
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
