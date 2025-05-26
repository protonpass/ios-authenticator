//
// ImageParsingFailureReason.swift
// Proton Authenticator - Created on 05/03/2025.
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

public enum ImageParsingFailureReason: CustomDebugStringConvertible, Equatable, Sendable {
    case errorProcessingImage
    case importFailed
    case failedDetectingQRCode
    case qrCodeEmpty

    public var debugDescription: String {
        switch self {
        case .errorProcessingImage:
            String(localized: "Error processing image", bundle: .module)
        case .importFailed:
            String(localized: "Error importing image", bundle: .module)
        case .failedDetectingQRCode:
            String(localized: "Error detecting QR code", bundle: .module)
        case .qrCodeEmpty:
            String(localized: "Empty QR code", bundle: .module)
        }
    }
}
