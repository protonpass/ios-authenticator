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

// import Foundation
//
// @Observable @MainActor
// final class ScannerViewModel: Sendable {
//
//    init() {
//        setUp()
//    }
// }
//
// private extension ScannerViewModel {
//    func setUp() {
//    }
// }

#if os(iOS)
import DataLayer
import DocScanner
import Factory
import Foundation

// import OneTimePassword

@Observable @MainActor
final class ScannerViewModel {
    var scanning = true
    var regionOfInterest: CGRect?
    private(set) var shouldDismiss = false
    var displayErrorAlert = false
    private(set) var creationError: Error?

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.entryDataService)
    private(set) var entryDataService

    private var task: Task<Void, Never>?
    private var hasPayload: Bool = false

    init() {
        setUp()
    }

    func processPayload(results: Result<ScanResult?, Error>) {
        task?.cancel()
        task = Task {
            switch results {
            case let .success(result):
                guard let barcode = result as? Barcode, !hasPayload else { return }
                hasPayload = true
                do {
                    try await entryDataService.generateEntry(from: barcode.payload)
                    shouldDismiss = true
                } catch {
                    handleError(error)
                }
            case let .failure(error):
                handleError(error)
            }
        }
    }

    func clean() {
        hasPayload = false
        creationError = nil
    }
}

private extension ScannerViewModel {
    func setUp() {}

    func handleError(_ error: Error) {
        creationError = error
        displayErrorAlert.toggle()
    }
}
#endif
