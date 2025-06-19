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

import AuthenticatorRustCore

// periphery:ignore
import DataLayer
import DocScanner
import FactoryKit
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
    private(set) var shouldEnterManually = false

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

    #if os(iOS)
    @ObservationIgnored
    @LazyInjected(\ToolsContainer.hapticsManager)
    private var hapticsManager
    #endif

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

    @ObservationIgnored
    let scanResponsePublisher: PassthroughSubject<Result<ScanResult, Error>, Never> = .init()

    init() {
        setUp()
    }

    deinit {
        task?.cancel()
        task = nil
    }

    func processPayload(results: Result<ScanResult, Error>) {
        if Task.isCancelled { return }

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
                    let config = AlertConfiguration.noCameraAccess { [weak self] in
                        guard let self else { return }
                        task?.cancel()
                        shouldEnterManually = true
                    }
                    alertService.showAlert(.sheet(config))
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
        cancellables.removeAll()
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

        scanResponsePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] scanResult in
                guard let self else { return }
                processPayload(results: scanResult)
            }
            .store(in: &cancellables)
    }

    func handleError(_ error: String) {
        if Task.isCancelled { return }
        alertService.showError(error, mainDisplay: false)

        #if os(iOS)
        hapticsManager(.notify(.error))
        #endif
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
                handleError(#localized("Could not process the image", bundle: .module))
            }
        }
    }

    func generateEntry(from barcodePayload: String) async {
        do {
            if Task.isCancelled { return }
            try await entryDataService.insertAndRefreshEntry(from: barcodePayload)
            shouldDismiss = true
            #if os(iOS)
            hapticsManager(.notify(.success))
            #endif
        } catch AuthError.generic(.duplicatedEntry) {
            if Task.isCancelled { return }
            handleError(#localized("This item already exists", bundle: .module))
        } catch AuthenticatorError.Unknown {
            if Task.isCancelled { return }
            handleError("Could not decipher the QR code, seems to be invalid.")
        } catch {
            if Task.isCancelled { return }
            handleError(error.localizedDescription)
        }
    }
}
#endif
