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
import FactoryKit
import Foundation
import Macro
import Models
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

public extension View {
    func importingService(_ showImportOptions: Binding<Bool>, onMainDisplay: Bool) -> some View {
        modifier(ImportingServiceModifier(showImportOptions: showImportOptions, mainDisplay: onMainDisplay))
    }
}

enum FocusField: Hashable {
    case field
}

struct ImportingServiceModifier: ViewModifier {
    @State private var viewModel: ImportViewModel
    @State private var showImportFromGoogleOptions = false
    @State private var showPhotosPicker = false
    @State private var showScanner = false
    @FocusState private var focusedField: FocusField?
    @State private var option: ImportOption?

    @Environment(\.colorScheme) private var colorScheme
    @Binding var showImportOptions: Bool

    init(showImportOptions: Binding<Bool>, mainDisplay: Bool) {
        _viewModel = .init(wrappedValue: ImportViewModel(mainDisplay: mainDisplay))
        _showImportOptions = showImportOptions
    }

    func body(content: Content) -> some View {
        content
            .importOptionsDialog(isPresented: $showImportOptions, onSelect: showExplanation)
            .importFromGoogleOptionsDialog(isPresented: $showImportFromGoogleOptions,
                                           onSelect: handle)
            .sheet(isPresented: $option.mappedToBool()) {
                explanationView()
            }
            .sheet(isPresented: $viewModel.showPasswordSheet) {
                passwordView()
            }
        #if os(iOS)
            .sheet(isPresented: $showScanner) {
                DataScanner(with: .barcode,
                            startScanning: $viewModel.scanning,
                            automaticDismiss: true) { results in
                    viewModel.processPayload(results: results)
                }.overlay(alignment: .topTrailing) {
                    Button {
                        showScanner = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24)
                            .foregroundStyle(.textNorm)
                    }
                    .adaptiveButtonStyle()
                    .padding()
                }
            }
        #endif
            .photosPicker(isPresented: $showPhotosPicker,
                          selection: $viewModel.imageSelection,
                          maxSelectionCount: 10,
                          matching: .images,
                          photoLibrary: .shared())
            .fileImporter(isPresented: $viewModel.showImporter.mappedToBool(),
                          allowedContentTypes: viewModel.showImporter?.autorizedFileExtensions ?? [],
                          allowsMultipleSelection: false,
                          onCompletion: viewModel.processImportedFile)
    }

    @ViewBuilder
    func explanationView() -> some View {
        if let option {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Spacer()
                    Button { self.option = nil } label: {
                        Image(systemName: "xmark.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24)
                            .foregroundStyle(.textNorm.opacity(0.7))
                    }
                    .adaptiveButtonStyle()
                    .padding(16)
                }

                HStack(spacing: 25) {
                    Image(option.iconName, bundle: .module)
                        .resizable()
                        .frame(width: 74, height: 74)
                    Image(.arrow)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32)

                    Image(.authIcon)
                        .resizable()
                        .frame(width: 74, height: 74)
                    Spacer()
                }
                .frame(height: 170)
                .padding(.horizontal, 32)

                Text(#localized("Import codes from") + " " + option.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(.textNorm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 32)
                Text(option.explanation)
                    .font(.title3)
                    .foregroundStyle(.textWeak)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 32)
                Spacer()
                CapsuleButton(title: "Import", textColor: .white, style: .borderedFilled, action: {
                    handle(option)
                    self.option = nil
                })
                .padding(.bottom, 90)
                .padding(.horizontal, 32)
            }
            .fullScreenMainBackground()
        }
    }

    func showExplanation(_ selectedOption: ImportOption) {
        option = selectedOption
    }

    func handle(_ selectedOption: ImportOption) {
        switch selectedOption {
        case .googleAuthenticator:
            showImportFromGoogleOptions.toggle()
        default:
            viewModel.importEntries(from: selectedOption)
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

    func passwordView() -> some View {
        VStack {
            HStack(alignment: .top) {
                Spacer()
                Button {
                    viewModel.showPasswordSheet = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24)
                        .foregroundStyle(.textNorm.opacity(0.7))
                }
                .adaptiveButtonStyle()
            }
            .frame(height: 60)
            .padding(.trailing, 16)
            VStack(alignment: .center, spacing: 30) {
                VStack(spacing: 8) {
                    Text("Protected file", bundle: .module)
                        .font(.title)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.textNorm)
                        .fontWeight(.bold)
                    Text("Your import file is protected by a password. Please enter the password to proceed.",
                         bundle: .module)
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.textWeak)
                }

                SecureField("Password", text: $viewModel.password)
                    .font(.title3)
                    .focused($focusedField, equals: .field)
                    .autocorrectionDisabled(true)
                #if os(iOS)
                    .textInputAutocapitalization(.never)
                #endif
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .foregroundStyle(.clear)
                            .frame(height: 1)
                            .background(colorScheme == .light ? .black.opacity(0.08) : Color.white
                                .opacity(0.12))
                    }

                CapsuleButton(title: "Import",
                              textColor: .white,
                              style: .borderedFilled) {
                    viewModel.encryptedImport()
                }.disabled(viewModel.password.isEmpty)
                Spacer()
            }
            .padding(.horizontal, 36)
        }
        .defaultFocus($focusedField, .field)
        .fullScreenMainBackground()
        .onChange(of: viewModel.showPasswordSheet) {
            if viewModel.showPasswordSheet {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                    focusedField = .field
                }
            }
        }
        .alert("Wrong password",
               isPresented: $viewModel.showWrongPasswordAlert,
               actions: {
                   Button("Cancel", role: .cancel) {
                       viewModel.showPasswordSheet = false
                   }
                   Button("Retry") {
                       viewModel.password = ""
                   }
               })
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
                Button { onSelect(option) } label: {
                    Text(verbatim: option.title)
                }
            }
        }
    }

    func importFromGoogleOptionsDialog(isPresented: Binding<Bool>,
                                       onSelect: @escaping (GoogleImportType) -> Void) -> some View {
        confirmationDialog("Select your provider",
                           isPresented: isPresented,
                           titleVisibility: .hidden) {
            ForEach(GoogleImportType.allCases, id: \.self) { option in
                if displayGoogleImportOption(option) {
                    Button { onSelect(option) } label: {
                        Text(option.title, bundle: .module)
                    }
                }
            }
        }
    }

    func displayGoogleImportOption(_ option: GoogleImportType) -> Bool {
        #if os(iOS)
        if AppConstants.isMobile
            || (ProcessInfo.processInfo.isiOSAppOnMac && option != .scanQrCode) {
            return true
        } else {
            return false
        }
        #else
        option == .scanQrCode ? false : true
        #endif
    }
}

@Observable @MainActor
final class ImportViewModel {
    var showImporter: ImportOption?
    var password: String = ""
    var showPasswordSheet = false
    var scanning = true
    var showWrongPasswordAlert = false

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.entryDataService)
    private(set) var entryDataService

    @ObservationIgnored
    @LazyInjected(\UseCaseContainer.parseImageQRCodeContent)
    private(set) var parseImageQRCodeContent

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.alertService)
    private var alertService

    #if os(iOS)
    @ObservationIgnored
    @LazyInjected(\ToolsContainer.hapticsManager)
    private var hapticsManager
    #endif

    @ObservationIgnored
    private var currentSelected: ImportOption?
    @ObservationIgnored
    private var provenance: TwofaImportSource?

    @ObservationIgnored var imageSelection: [PhotosPickerItem] = [] {
        didSet {
            imageSelectionStream.send(imageSelection)
        }
    }

    @ObservationIgnored
    private var cancellables = Set<AnyCancellable>()
    @ObservationIgnored
    private let imageSelectionStream: CurrentValueSubject<[PhotosPickerItem], Never> = .init([])

    private let mainDisplay: Bool

    init(mainDisplay: Bool) {
        self.mainDisplay = mainDisplay
        imageSelectionStream
            .receive(on: DispatchQueue.main)
            .compactMap(\.self)
            .sink { [weak self] newImageSelection in
                guard let self, !newImageSelection.isEmpty else { return }
                parseImage(newImageSelection)
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
                  let currentSelected else {
                return
            }

            guard currentSelected.autorizedFileExtensions.contains(type) else {
                alertService.showError(#localized("Forbidden file type for this provenance", bundle: .module),
                                       mainDisplay: mainDisplay,
                                       action: nil)
                return
            }
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
                        alertService.showError(error, mainDisplay: mainDisplay, action: nil)
                    }
                }
                url.stopAccessingSecurityScopedResource()
            }
        case let .failure(error):
            alertService.showError(error, mainDisplay: mainDisplay, action: nil)
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
                password = ""
                showWrongPasswordAlert = true
            }
        }
    }

    func parseImage(_ imageSelection: [PhotosPickerItem]) {
        Task { [weak self] in
            guard let self else {
                return
            }
            defer {
                self.imageSelection = []
            }
            var numberOfImportedEntries = 0
            var errors = [Error]()
            for selection in imageSelection {
                do {
                    let content = try await parseImageQRCodeContent(imageSelection: selection)
                    numberOfImportedEntries += try await entryDataService
                        .importEntries(from: .googleQr(contents: content))
                } catch {
                    errors.append(error)
                }
            }
            showCompletion(numberOfImportedEntries)
            if !errors.isEmpty {
                alertService
                    .showError(#localized("Several images could not be processed. See logs for more details.",
                                          bundle: .module),
                               mainDisplay: mainDisplay,
                               action: nil)
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
                    alertService.showError(error, mainDisplay: mainDisplay, action: nil)
                }
            } catch {
                alertService.showError(error, mainDisplay: mainDisplay, action: nil)
            }
        }
    }
    #endif

    func showCompletion(_ numberOfEntries: Int) {
        let hasNewEntries = numberOfEntries > 0

        let config = AlertConfiguration(title: hasNewEntries ? "Codes imported" : "No codes imported",
                                        titleBundle: .module,
                                        message: .localized(hasNewEntries ?
                                            "Successfully imported \(numberOfEntries) items" :
                                            "No new codes detected",
                                            .module),
                                        actions: [.ok])
        let alert: AlertDisplay = mainDisplay ? .main(config) : .sheet(config)
        alertService.showAlert(alert)
        #if os(iOS)
        hapticsManager(.notify(.success))
        #endif
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
        case .enteAuth, .twoFas:
            [.text, .plainText, .twoFAS]
        case .protonAuthenticator:
            [.text, .plainText, .json]
        case .googleAuthenticator:
            [.image, .jpeg, .png]
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

extension UTType {
    static let twoFAS = UTType(exportedAs: "me.proton.2fas")
}

// swiftlint:disable line_length
private extension ImportOption {
    var explanation: LocalizedStringKey {
        switch self {
        case .googleAuthenticator:
            "To export codes from Google Authenticator, you'll need to use the app's built-in **“Transfer accounts”** feature, which generates a QR code for transferring accounts to a new device."
        case .twoFas:
            "Open 2FAS Authenticator and enter the “Settings” section.\n\nThen enter the “2FAS Backup” feature.\n\nEnter the Export tool and click the “Export to file” button."
        case .aegisAuthenticator:
            "To export codes from Aegis Authenticator, navigate to the app's Settings, find the ”Import & Export” section, and select the export option.\n\nYou can choose to export as an encrypted database, or as a plain text file."
        case .bitwardenAuthenticator:
            "To export data from Bitwarden Authenticator, open the “Settings” tab and tap the “Export” button.\n\nYou can choose to export your data as a . json or . csv file."
        case .enteAuth:
            "To export data from Ente Auth, open the “Settings” tab and look for “Import/Export” options.\n\nTap “Export Codes” and then “Ente Encrypted export”.\n\nThis creates an encrypted backup file (usually .ente or .json) containing all your codes."
        case .lastPassAuthenticator:
            "To export 2FA codes (TOTP) from LastPass, you'll need to export your vault data as a CSV file.  \n\nOpen the LastPass browser extension and log in.  Go to Account → Fix a problem yourself → Export vault items → Export data for use anywhere."
        case .protonAuthenticator:
            "To export codes from Proton Authenticator, navigate to the app's settings, find the “Mange your data” section, and select the export option."
        }
    }
}

// swiftlint:enable line_length
