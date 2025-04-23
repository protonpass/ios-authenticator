//
// Import+ViewModifier.swift
// Proton Authenticator - Created on 21/03/2025.
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

import Combine
import CommonUtilities
import DataLayer
#if os(iOS)
import DocScanner
#endif
import Factory
import Foundation
import Models
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct ImportingServiceModifier: ViewModifier {
    @State private var viewModel: ImportViewModel
    @State private var showImportFromGoogleOptions = false
    @State private var showPhotosPicker = false
    @State private var showScanner = false

    @Binding var showImportOptions: Bool

    init(showImportOptions: Binding<Bool>, mainDisplay: Bool) {
        _viewModel = .init(wrappedValue: ImportViewModel(mainDisplay: mainDisplay))
        _showImportOptions = showImportOptions
    }

    func body(content: Content) -> some View {
        content
            .importOptionsDialog(isPresented: $showImportOptions, onSelect: handle)
            .importFromGoogleOptionsDialog(isPresented: $showImportFromGoogleOptions,
                                           onSelect: handle)
            .sheet(isPresented: $viewModel.showPasswordSheet) {
                VStack {
                    Text("Your import file is password protected. Please enter the password to proceed.",
                         bundle: .module)
                    TextField("Password", text: $viewModel.password)

                    CapsuleButton(title: "Import",
                                  textColor: .white,
                                  style: .borderedFilled) {
                        viewModel.encryptedImport()
                    }.disabled(viewModel.password.isEmpty)
                }
                .mainBackground()
            }
        #if os(iOS)
            .sheet(isPresented: $showScanner) {
                DataScanner(with: .barcode,
                            startScanning: $viewModel.scanning,
                            automaticDismiss: true) { results in
                    viewModel.processPayload(results: results)
                }
            }
        #endif
            .photosPicker(isPresented: $showPhotosPicker,
                          selection: $viewModel.imageSelection,
                          matching: .images,
                          photoLibrary: .shared())
            .fileImporter(isPresented: $viewModel.showImporter.mappedToBool(),
                          allowedContentTypes: viewModel.showImporter?.autorizedFileExtensions ?? [],
                          allowsMultipleSelection: false,
                          onCompletion: viewModel.processImportedFile)
    }

    func handle(_ option: ImportOption) {
        switch option {
        case .googleAuthenticator:
            showImportFromGoogleOptions.toggle()
        default:
            viewModel.importEntries(from: option)
        }
    }

    func handle(_ option: GoogleImportType) {
        switch option {
        case .scanQrCode:
            showScanner.toggle()
        case .pickPhoto:
            showPhotosPicker.toggle()
        case .importFromFiles:
            viewModel.importEntries(from: .googleAuthenticator)
        }
    }
}

private extension View {
    // periphery:ignore
    func importOptionsDialog(isPresented: Binding<Bool>,
                             onSelect: @escaping (ImportOption) -> Void) -> some View {
        confirmationDialog("Select your provider",
                           isPresented: isPresented,
                           titleVisibility: .visible) {
            ForEach(ImportOption.allCases, id: \.self) { option in
                Button(action: { onSelect(option) }, label: {
                    Text(verbatim: option.title)
                })
            }
        }
    }

    func importFromGoogleOptionsDialog(isPresented: Binding<Bool>,
                                       onSelect: @escaping (GoogleImportType) -> Void) -> some View {
        confirmationDialog("Select your provider",
                           isPresented: isPresented,
                           titleVisibility: .hidden) {
            ForEach(GoogleImportType.allCases, id: \.self) { option in
                Button(action: { onSelect(option) }, label: {
                    Text(option.title, bundle: .module)
                })
            }
        }
    }
}

public extension View {
    func importingService(_ showImportOptions: Binding<Bool>, onMainDisplay: Bool) -> some View {
        modifier(ImportingServiceModifier(showImportOptions: showImportOptions, mainDisplay: onMainDisplay))
    }
}

@Observable @MainActor
final class ImportViewModel {
    var showImporter: ImportOption?
    var password: String = ""
    var showPasswordSheet = false
    var scanning = true

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.entryDataService)
    private(set) var entryDataService

    @ObservationIgnored
    @LazyInjected(\UseCaseContainer.parseImageQRCodeContent)
    private(set) var parseImageQRCodeContent

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.alertService)
    private var alertService

    @ObservationIgnored
    private var currentSelected: ImportOption?
    @ObservationIgnored
    private var provenance: TwofaImportSource?

    @ObservationIgnored var imageSelection: PhotosPickerItem? {
        didSet {
            imageSelectionStream.send(imageSelection)
        }
    }

    @ObservationIgnored
    private var cancellables = Set<AnyCancellable>()
    @ObservationIgnored
    private let imageSelectionStream: CurrentValueSubject<PhotosPickerItem?, Never> = .init(nil)

    private let mainDisplay: Bool

    init(mainDisplay: Bool) {
        self.mainDisplay = mainDisplay
        imageSelectionStream
            .receive(on: DispatchQueue.main)
            .compactMap(\.self)
            .sink { [weak self] imageSelection in
                guard let self else { return }
                parseImage(imageSelection)
            }
            .store(in: &cancellables)
    }

    func importEntries(from option: ImportOption) {
        currentSelected = option
        showImporter = option
    }

    func processImportedFile(_ result: Result<[URL], any Error>) {
        provenance = nil
        switch result {
        case let .success(urls):
            guard let url = urls.first,
                  let type = url.mimeType,
                  let currentSelected,
                  currentSelected.autorizedFileExtensions.contains(type) else { return }
            Task { [weak self] in
                guard let self else { return }
                if url.startAccessingSecurityScopedResource() {
                    do {
                        let fileContent = try String(contentsOf: url, encoding: .utf8)
                        provenance = currentSelected.importDestination(content: fileContent,
                                                                       type: type,
                                                                       password: password.nilIfEmpty)
                        guard let provenance else { return }
                        let numberOfImportedEntries = try await entryDataService.importEntries(from: provenance)
                        showCompletion(numberOfImportedEntries)
                    } catch ImportException.MissingPassword {
                        showPasswordSheet.toggle()
                    } catch {
                        alertService.showError(error.localizedDescription, mainDisplay: mainDisplay, action: nil)
                    }
                }
                url.stopAccessingSecurityScopedResource()
            }
        case let .failure(error):
            alertService.showError(error.localizedDescription, mainDisplay: mainDisplay, action: nil)
        }
    }

    func encryptedImport() {
        guard let provenance, !password.isEmpty else {
            return
        }
        let updatedProvenance = provenance.updatePassword(password)
        Task { [weak self] in
            guard let self else { return }
            do {
                let numberOfImportedEntries = try await entryDataService.importEntries(from: updatedProvenance)
                showCompletion(numberOfImportedEntries)
            } catch {
                alertService.showError(error.localizedDescription, mainDisplay: mainDisplay, action: nil)
            }
        }
    }

    func parseImage(_ imageSelection: PhotosPickerItem) {
        Task { [weak self] in
            guard let self else {
                return
            }
            do {
                let content = try await parseImageQRCodeContent(imageSelection: imageSelection)
                let numberOfImportedEntries = try await entryDataService
                    .importEntries(from: .googleQr(contents: content))
                showCompletion(numberOfImportedEntries)
            } catch {
                alertService.showError(error.localizedDescription, mainDisplay: mainDisplay, action: nil)
            }
        }
    }

    #if os(iOS)
    func processPayload(results: Result<ScanResult?, Error>) {
        Task { [weak self] in
            guard let self else { return }
            do {
                switch results {
                case let .success(result):
                    guard let barcode = result as? Barcode else { return }
                    let numberOfImportedEntries = try await entryDataService
                        .importEntries(from: .googleQr(contents: barcode.payload))
                    showCompletion(numberOfImportedEntries)
                case let .failure(error):
                    alertService.showError(error.localizedDescription, mainDisplay: mainDisplay, action: nil)
                }
            } catch {
                alertService.showError(error.localizedDescription, mainDisplay: mainDisplay, action: nil)
            }
        }
    }
    #endif

    func showCompletion(_ numberOfEntries: Int) {
        let config = AlertConfiguration(title: "Codes imported",
                                        titleBundle: .module,
                                        message: .localized("Successfully imported \(numberOfEntries) items",
                                                            .module),
                                        actions: [.ok])
        let alert: AlertDisplay = mainDisplay ? .main(config) : .sheet(config)
        alertService.showAlert(alert)
    }
}

private extension UTType {
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

private extension URL {
    var mimeType: UTType? {
        let pathExtension = pathExtension

        return UTType(filenameExtension: pathExtension)
    }
}

private extension ImportOption {
    // periphery:ignore
    var title: String {
        switch self {
        case .googleAuthenticator:
            "Google Authenticator"
        case .twoFas:
            "2FAS"
        case .aegisAuthenticator:
            "Aegis Authenticator"
        case .bitwardenAuthenticator:
            "Bitwarden Authenticator"
        case .enteAuth:
            "Ente Auth"
        case .lastPassAuthenticator:
            "LastPass Authenticator"
        case .protonAuthenticator:
            "Proton Authenticator"
        }
    }

    var autorizedFileExtensions: [UTType] {
        switch self {
        case .aegisAuthenticator:
            [.json, .text, .plainText]
        case .bitwardenAuthenticator:
            [.json, .commaSeparatedText]
        case .lastPassAuthenticator:
            [.json]
        case .enteAuth, .protonAuthenticator, .twoFas:
            [.text, .plainText]
        case .googleAuthenticator:
            [.image]
        }
    }

    func importDestination(content: String, type: UTType, password: String?) -> TwofaImportSource {
        switch self {
        case .twoFas:
            .twofas(contents: content, password: password)
        case .aegisAuthenticator:
            .aegis(contents: type.toTwofaImportFileType(content: content), password: password)
        case .bitwardenAuthenticator:
            .bitwarden(contents: type.toTwofaImportFileType(content: content))
        case .enteAuth:
            .ente(contents: content)
        case .googleAuthenticator:
            .googleQr(contents: content)
        case .lastPassAuthenticator:
            .lastpass(contents: type.toTwofaImportFileType(content: content))
        case .protonAuthenticator:
            .protonAuthenticator(contents: content)
        }
    }
}

private extension GoogleImportType {
    var title: LocalizedStringKey {
        switch self {
        case .scanQrCode:
            "Scan a QR code"
        case .pickPhoto:
            "Choose a Photo"
        case .importFromFiles:
            "Import from Files"
        }
    }
}
