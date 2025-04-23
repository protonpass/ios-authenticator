//
//
// ScannerViewModel.swift
// Proton Authenticator - Created on 28/02/2025.
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

#if os(iOS)
import Combine
import DocScanner
import Factory
import Foundation
import Macro
import Models
import PhotosUI
import SwiftUI
import VisionKit

@Observable @MainActor
final class ScannerViewModel {
    var scanning = true
    private(set) var shouldDismiss = false

    @ObservationIgnored var imageSelection: PhotosPickerItem? {
        didSet {
            imageSelectionStream.send(imageSelection)
        }
    }

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.entryDataService)
    private(set) var entryDataService

    @ObservationIgnored
    @LazyInjected(\UseCaseContainer.parseImageQRCodeContent)
    private(set) var parseImageQRCodeContent

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.alertService)
    var alertService

    @ObservationIgnored
    private var task: Task<Void, Never>?
    @ObservationIgnored
    private var hasPayload = false
    @ObservationIgnored
    private let imageSelectionStream: CurrentValueSubject<PhotosPickerItem?, Never> = .init(nil)
    @ObservationIgnored
    private var cancellables = Set<AnyCancellable>()

    init() {
        setUp()
    }

    deinit {
        task?.cancel()
        task = nil
    }

    func processPayload(results: Result<ScanResult?, Error>) {
        task?.cancel()
        task = Task { [weak self] in
            guard let self else { return }
            switch results {
            case let .success(result):
                guard let barcode = result as? Barcode, !hasPayload else { return }
                hasPayload = true
                await generateEntry(from: barcode.payload)
            case let .failure(error):
                if Task.isCancelled { return }
                if let error = error as? DataScannerViewController.ScanningUnavailable,
                   error == .cameraRestricted {
                    if Task.isCancelled { return }
                    // swiftlint:disable:next line_length
                    handleError(#localized("Camera usage restricted. Please modify your device settings to be able to scan barcodes.",
                                           bundle: .module))
                } else {
                    if Task.isCancelled { return }
                    handleError(error.localizedDescription)
                }
            }
        }
    }

    func clean() {
        hasPayload = false
        task?.cancel()
        task = nil
    }
}

private extension ScannerViewModel {
    func setUp() {
        imageSelectionStream
            .receive(on: DispatchQueue.main)
            .compactMap(\.self)
            .sink { [weak self] imageSelection in
                guard let self else { return }
                parseImage(imageSelection)
            }
            .store(in: &cancellables)
    }

    func handleError(_ error: String) {
        alertService.showError(error, mainDisplay: false) { [weak self] in
            guard let self else {
                return
            }
            clean()
        }
    }

    func parseImage(_ imageSelection: PhotosPickerItem) {
        Task { [weak self] in
            guard let self else {
                return
            }
            do {
                let content = try await parseImageQRCodeContent(imageSelection: imageSelection)
                await generateEntry(from: content)
            } catch {
                if Task.isCancelled { return }

                handleError(#localized("Could not parse the image", bundle: .module))
            }
        }
    }

    func generateEntry(from barcodePayload: String) async {
        do {
            if Task.isCancelled { return }
            try await entryDataService.insertAndRefreshEntry(from: barcodePayload)
            shouldDismiss = true
        } catch AuthError.generic(.duplicatedEntry) {
            if Task.isCancelled { return }
            handleError(#localized("This item is already saved on the device", bundle: .module))
        } catch {
            if Task.isCancelled { return }
            handleError(error.localizedDescription)
        }
    }
}
#endif
