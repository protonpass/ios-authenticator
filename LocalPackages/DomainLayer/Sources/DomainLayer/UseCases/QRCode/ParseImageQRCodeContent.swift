//
//
// ParseImageQRCodeContent.swift
// Proton Authenticator - Created on 03/03/2025.
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

import CommonUtilities
import CoreTransferable
import Models
import PhotosUI
import SwiftUI

public protocol ParseImageQRCodeContentUseCase: Sendable {
    func execute(imageSelection: PhotosPickerItem) async throws -> String
}

public extension ParseImageQRCodeContentUseCase {
    func callAsFunction(imageSelection: PhotosPickerItem) async throws -> String {
        try await execute(imageSelection: imageSelection)
    }
}

public final class ParseImageQRCodeContent: ParseImageQRCodeContentUseCase {
    public init() {}

    public func execute(imageSelection: PhotosPickerItem) async throws -> String {
        guard let image = try await imageSelection.loadTransferable(type: QRCodeImage.self) else {
            throw AuthError.imageParsing(.errorProcessingImage)
        }
        return try parseImageForCode(image: image)
    }

    private func parseImageForCode(image: QRCodeImage) throws -> String {
        guard let ciImage = image.image.toCiImage,
              let detector = CIDetector(ofType: CIDetectorTypeQRCode,
                                        context: nil,
                                        options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]),
              let features = detector.features(in: ciImage) as? [CIQRCodeFeature]
        else {
            throw AuthError.imageParsing(.failedDetectingQRCode)
        }
        let qrCodeContent = features.compactMap(\.messageString).joined()

        guard !qrCodeContent.isEmpty else {
            throw AuthError.imageParsing(.qrCodeEmpty)
        }

        return qrCodeContent
    }
}

// MARK: - Utils

private struct QRCodeImage: Transferable {
    #if canImport(AppKit)
    let image: NSImage
    #elseif canImport(UIKit)
    let image: UIImage
    #endif

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { data in
            #if canImport(AppKit)
            guard let nsImage = NSImage(data: data) else {
                throw ParseImageError.importFailed
            }
            return QRCodeImage(image: nsImage)
            #elseif canImport(UIKit)
            guard let uiImage = UIImage(data: data) else {
                throw AuthError.imageParsing(.importFailed)
            }
            return QRCodeImage(image: uiImage)
            #else
            throw ParseImageError.importFailed
            #endif
        }
    }
}
