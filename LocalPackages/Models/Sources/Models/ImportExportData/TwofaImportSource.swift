//
// TwofaImportSource.swift
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

public enum TwofaImportSource: Sendable, Equatable {
    case twofas(contents: String, password: String?)
    case aegis(contents: TwofaImportFileType, password: String?)
    case bitwarden(contents: TwofaImportFileType)
    case ente(contents: String)
    case googleQr(contents: String)
    case lastpass(contents: TwofaImportFileType)
    case protonAuthenticator(contents: String)
    case protonPass(contents: Data)

    public func updatePassword(_ password: String?) -> Self {
        switch self {
        case let .twofas(contents: contents, _):
            .twofas(contents: contents, password: password)
        case let .aegis(contents: contents, _):
            .aegis(contents: contents, password: password)
        default:
            self
        }
    }

    public var name: String {
        switch self {
        case .twofas: "2FAS"
        case .aegis: "Aegis"
        case .bitwarden: "Bitwarden"
        case .ente: "Ente"
        case .googleQr: "Google"
        case .lastpass: "Lastpass"
        case .protonAuthenticator: "Proton Authenticator"
        case .protonPass: "Proton Pass"
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
