//
// DeepLinkService.swift
// Proton Authenticator - Created on 13/03/2025.
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

import CommonUtilities
import Foundation
import Models

private enum DeeplinkType {
    case otpauth
    case other(String)
    case unknown
}

private extension URL {
    var linkType: DeeplinkType {
        if scheme == "otpauth" {
            .otpauth
        } else if let scheme {
            .other(scheme)
        } else {
            .unknown
        }
    }
}

public protocol DeepLinkServicing: Sendable {
    func handleDeeplink(_ url: URL) async throws
}

public final class DeepLinkService: DeepLinkServicing {
    private let service: any EntryDataServiceProtocol
    private let alertService: any AlertServiceProtocol

    public init(service: any EntryDataServiceProtocol,
                alertService: any AlertServiceProtocol) {
        self.service = service
        self.alertService = alertService
    }

    /// Handles the incoming URL and performs validations before acknowledging.
    public func handleDeeplink(_ url: URL) async throws {
        switch url.linkType {
        case .otpauth:
            try await process(url: url)
        default:
            return
        }
    }
}

// MARK: - Utils

// swiftlint:disable line_length
private extension DeepLinkService {
    func process(url: URL) async throws {
        let uri = url.absoluteString.decodeHTMLAndPercent
        guard !uri.isEmpty else {
            throw AuthError.deeplinking(.couldNotDecodeURL)
        }

        let entry = try await service.getEntry(from: uri)
        await alertService.showAlert(.main(AlertConfiguration(title: "Warning",
                                                              message: .localized("Do you want to add this entry for the account \(entry.name)?"),
                                                              actions: [
                                                                  .init(title: "Yes", action: {
                                                                      Task { [weak self] in
                                                                          guard let self else { return }
                                                                          try? await service
                                                                              .insertAndRefresh(entry: entry)
                                                                      }
                                                                  }),
                                                                  .init(title: "No", role: .cancel)
                                                              ])))
    }
}

// swiftlint:enable line_length
