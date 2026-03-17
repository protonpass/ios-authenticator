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
import DomainLayer
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
import VisionKit

// swiftlint:disable file_length
public enum ImportingContext: Sendable {
    case onboarding, homepage, settings

    var isMainDisplay: Bool {
        if case .homepage = self {
            true
        } else {
            false
        }
    }
}

extension View {
    func importingService(_ showImportOptions: Binding<Bool>,
                          context: ImportingContext,
                          onComplete: (@MainActor () -> Void)? = nil) -> some View {
        modifier(ImportingServiceModifier(showImportOptions: showImportOptions,
                                          context: context,
                                          onComplete: onComplete))
    }
}

private enum FocusField: Hashable {
    case field
}

struct ImportingServiceModifier: ViewModifier {
    @StateObject private var viewModel: ImportViewModel
    @State private var showImportFromGoogleOptions = false
    @State private var showPhotosPicker = false
    @State private var showScanner = false
    @FocusState private var focusedField: FocusField?
    @State private var option: ImportOption?

    @Environment(\.colorScheme) private var colorScheme
    @Binding var showImportOptions: Bool

    init(showImportOptions: Binding<Bool>,
         context: ImportingContext,
         onComplete: (@MainActor () -> Void)?) {
        _viewModel = .init(wrappedValue: ImportViewModel(context: context,
                                                         onComplete: onComplete))
        _showImportOptions = showImportOptions
    }

    func body(content: Content) -> some View {
        content
            .importFromGoogleOptionsDialog(isPresented: $showImportFromGoogleOptions,
                                           onSelect: handle)
            .sheet(isPresented: $showImportOptions) {
                ImportView { option = $0 }
            }
            .sheet(item: $option) { option in
                ExplanationView(option: option,
                                handle: handle)
            }
            .sheet(isPresented: $viewModel.showPasswordSheet) {
                passwordView()
            }
        #if os(iOS)
            .sheet(isPresented: $showScanner) {
                scannerView()
            }
        #endif
            .photosPicker(isPresented: $showPhotosPicker,
                          selection: $viewModel.imageSelection,
                          maxSelectionCount: 10,
                          matching: .images,
                          photoLibrary: .shared())
            .fileImporter(isPresented: $viewModel.showImporter.mappedToBool(),
                          allowedContentTypes: viewModel.showImporter?.authorizedFileExtensions ?? [],
                          allowsMultipleSelection: viewModel.showImporter == .googleAuthenticator,
                          onCompletion: viewModel.processImportedFile)
            .showSpinner(viewModel.importing)
            .onAppear {
                viewModel.addContext()
            }
            .onDisappear {
                viewModel.removeContext()
            }
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
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            switch status {
            case .authorized, .notDetermined:
                showScanner.toggle()

            case .denied, .restricted:
                viewModel.alertNoCameraPermission()

            @unknown default:
                showScanner.toggle()
            }

        case .pickPhoto:
            showPhotosPicker.toggle()

        case .importFromFiles:
            viewModel.importEntries(from: .googleAuthenticator)
        }
    }

    @ViewBuilder
    func scannerView() -> some View {
        if viewModel.unsupportedScanning {
            CameraView(session: viewModel.cameraSession)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear {
                    viewModel.setUpAndStartCameraSession()
                }
                .onDisappear {
                    viewModel.stopCameraSession()
                }
                .overlay {
                    VStack {
                        HStack {
                            Spacer()
                            Button {
                                showScanner = false
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 24)
                                    .foregroundStyle(.white)
                            }
                            .adaptiveButtonStyle()
                            .padding()
                        }
                        Spacer()
                        HStack {
                            Spacer()
                            Button { viewModel.takePhoto() } label: {
                                Image(.insetFilledCircle)
                                    .resizable()
                                    .frame(width: 60, height: 60)
                                    .foregroundStyle(.white)
                            }
                            .disabled(viewModel.takingPhoto)
                            .padding()
                            Spacer()
                        }
                    }
                }
                .showSpinner(viewModel.takingPhoto)
        } else {
            DataScanner(with: .barcode,
                        startScanning: $viewModel.scanning,
                        automaticDismiss: true,
                        resultStream: viewModel.scanResultStream)
                .overlay(alignment: .topTrailing) {
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

            VStack(alignment: .center) {
                Text("Protected file", bundle: .module)
                    .dynamicFont(size: 28, textStyle: .title1, weight: .bold)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.textNorm)

                Text("Your import file is protected by a password. Please enter the password to proceed.",
                     bundle: .module)
                    .dynamicFont(size: 20, textStyle: .title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.textWeak)
                    .padding(.bottom, 32)

                SecureField("Password", text: $viewModel.password)
                    .dynamicFont(size: 20, textStyle: .title3)
                    .focused($focusedField, equals: .field)
                    .autocorrectionDisabled(true)
                #if os(iOS)
                    .textInputAutocapitalization(.never)
                #endif

                Rectangle()
                    .foregroundStyle(.clear)
                    .frame(height: 1)
                    .background(colorScheme == .light ? .black.opacity(0.08) : .white.opacity(0.12))
                    .padding(.bottom, 32)

                CapsuleButton(title: "Import",
                              textColor: .white,
                              style: .borderedFilled,
                              action: viewModel.encryptedImport)
                    .disabled(viewModel.password.isEmpty)

                Spacer()
            }
            .padding(.horizontal, 36)
        }
        .defaultFocus($focusedField, .field)
        .fullScreenMainBackground()
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
    func importFromGoogleOptionsDialog(isPresented: Binding<Bool>,
                                       onSelect: @escaping (GoogleImportType) -> Void) -> some View {
        alert(Text("Import from Google Authenticator", bundle: .module),
              isPresented: isPresented) {
            ForEach(GoogleImportType.allCases, id: \.self) { option in
                if displayGoogleImportOption(option) {
                    Button { onSelect(option) } label: {
                        Text(option.title, bundle: .module)
                    }
                }
            }
            Button("Cancel", role: .cancel, action: {})
        }
    }

    func displayGoogleImportOption(_ option: GoogleImportType) -> Bool {
        #if os(iOS)
        if AppConstants.isMobile
            || (ProcessInfo.processInfo.isiOSAppOnMac && option != .scanQrCode) {
            return true
        }
        return false
        #else
        option == .scanQrCode ? false : true
        #endif
    }
}

@Observable @MainActor
private final class ImportViewModel: ObservableObject {
    var showImporter: ImportOption?
    var password: String = ""
    var showPasswordSheet = false {
        didSet {
            if !showPasswordSheet {
                password = ""
            }
        }
    }

    var scanning = true
    var showWrongPasswordAlert = false
    private(set) var importing = false
    private(set) var takingPhoto = false

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
    @LazyInjected(\ServiceContainer.cameraManager)
    private var cameraManager

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.settingsService)
    private var appSettings

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

    @ObservationIgnored
    private let onComplete: (@MainActor () -> Void)?

    @ObservationIgnored
    let scanResultStream = PassthroughSubject<Result<ScanResult, any Error>, Never>()

    @ObservationIgnored
    private var processTask: Task<Void, Never>?

    @ObservationIgnored
    private var parseTask: Task<Void, Never>?

    @ObservationIgnored
    let context: ImportingContext

    @ObservationIgnored
    @LazyInjected(\ToolsContainer.importingContexts)
    private var importingContexts: CurrentValueSubject<[ImportingContext], Never>

    var unsupportedScanning: Bool {
        appSettings.unsupportedScanning
    }

    var cameraSession: AVCaptureSession {
        cameraManager.session
    }

    init(context: ImportingContext,
         onComplete: (@MainActor () -> Void)?) {
        self.context = context
        self.onComplete = onComplete

        imageSelectionStream
            .receive(on: DispatchQueue.main)
            .compactMap(\.self)
            .sink { [weak self] newImageSelection in
                guard let self, !newImageSelection.isEmpty else { return }
                parseImage(newImageSelection)
            }
            .store(in: &cancellables)

        cameraManager.isTakingPhoto
            .sink { [weak self] value in
                guard let self else { return }
                takingPhoto = value
            }
            .store(in: &cancellables)

        cameraManager.takenPhoto
            .compactMap(\.self)
            .sink { [weak self] photo in
                guard let self else { return }
                parseCapturedPhoto(photo)
            }
            .store(in: &cancellables)

        scanResultStream
            // Debounce to mitigate duplicated results because camera scanning is too fast
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main, options: nil)
            .sink { [weak self] result in
                guard let self else { return }
                processPayload(results: result)
            }
            .store(in: &cancellables)
    }

    func addContext() {
        var currentContexts = importingContexts.value
        currentContexts.append(context)
        importingContexts.send(currentContexts)
    }

    func removeContext() {
        var currentContexts = importingContexts.value
        currentContexts.removeAll(where: { $0 == context })
        importingContexts.send(currentContexts)
    }

    func importEntries(from option: ImportOption) {
        currentSelected = option
        showImporter = option
    }

    // swiftlint:disable:next cyclomatic_complexity
    func processImportedFile(_ result: Result<[URL], any Error>) {
        provenance = nil
        switch result {
        case let .success(urls):
            guard let url = urls.first,
                  let type = url.mimeType,
                  let currentSelected else {
                return
            }

            let selectedMimeTypes = urls.compactMap(\.mimeType)
            guard selectedMimeTypes.allSatisfy({ type in
                currentSelected.authorizedFileExtensions.contains(type) }) else {
                let message = #localized("Importing from %1$@ doesn't support %2$@ file format.",
                                         bundle: .main,
                                         currentSelected.title,
                                         type.preferredFilenameExtension ?? type.identifier)
                showError(message)

                return
            }
            Task { [weak self] in
                guard let self else { return }
                defer { importing = false }
                var sources = [TwofaImportSource]()
                for url in urls {
                    if url.startAccessingSecurityScopedResource() {
                        do {
                            let fileHandle = try FileHandle(forReadingFrom: url)
                            let fileSize = try fileHandle.seekToEnd()
                            try fileHandle.close()

                            if fileSize > AppConstants.maxFileSizeInBytes {
                                throw AuthError.importing(.fileTooLarge)
                            }

                            let fileContent = try Data(contentsOf: url)
                            provenance =
                                try currentSelected.importDestination(content: fileContent,
                                                                      type: type,
                                                                      password: nil,
                                                                      parseImageQRCode: parseImageQRCodeContent)
                            guard let provenance else { return }
                            sources.append(provenance)
                        } catch {
                            showError(error.localizedDescription)
                            return
                        }
                    }
                    url.stopAccessingSecurityScopedResource()
                }

                do {
                    importing = true
                    let numberOfImportedEntries = try await entryDataService.importEntries(from: sources)
                    showCompletion(numberOfImportedEntries)
                } catch ImportException.MissingPassword {
                    showPasswordSheet.toggle()
                } catch ImportException.BadContent {
                    alertBadContentError(url)
                } catch let AuthError.importing(reason) where reason == .fileTooLarge {
                    alertFileTooLargeError(url)
                } catch {
                    showError(error.localizedDescription)
                }
            }

        case let .failure(error):
            showError(error.localizedDescription)
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
                showError(#localized("Several images could not be processed. See logs for more details.",
                                     bundle: .module))
            }
        }
    }

    #if os(iOS)
    func processPayload(results: Result<ScanResult, Error>) {
        guard processTask == nil, importingContexts.value.last == context else { return }
        processTask = Task { [weak self] in
            guard let self else { return }
            defer { processTask = nil }
            do {
                switch results {
                case let .success(result):
                    guard let barcode = result as? Barcode else { return }
                    let numberOfImportedEntries = try await entryDataService
                        .importEntries(from: .googleQr(contents: barcode.payload))
                    showCompletion(numberOfImportedEntries)

                case let .failure(error):
                    if error is DataScannerViewController.ScanningUnavailable {
                        appSettings.setUnsupportedScanning(true)
                    } else {
                        showError(error.localizedDescription)
                    }
                }
            } catch {
                showError(error.localizedDescription)
            }
        }
    }
    #endif

    func showCompletion(_ numberOfEntries: Int) {
        let hasNewEntries = numberOfEntries > 0

        let action: ActionConfig = if let onComplete {
            ActionConfig(title: "OK", titleBundle: .module, action: onComplete)
        } else {
            .ok
        }
        let config = AlertConfiguration(title: hasNewEntries ? "Codes imported" : "No codes imported",
                                        titleBundle: .module,
                                        message: .localized(hasNewEntries ?
                                            "Successfully imported \(numberOfEntries) items" :
                                            "No new codes detected",
                                            .module),
                                        actions: [action])
        showAlert(config)
        #if os(iOS)
        hapticsManager(.notify(.success))
        #endif
    }

    func alertNoCameraPermission() {
        let config = AlertConfiguration.noCameraAccess()
        showAlert(config)
    }

    func setUpAndStartCameraSession() {
        do {
            try cameraManager.setUpSession()
            cameraManager.startSession()
        } catch {
            showError(error.localizedDescription)
        }
    }

    func stopCameraSession() {
        cameraManager.stopSession()
    }

    func takePhoto() {
        do {
            try cameraManager.takePhoto()
        } catch {
            showError(error.localizedDescription)
        }
    }
}

private extension ImportViewModel {
    func alertFileTooLargeError(_ url: URL) {
        let message = #localized("File \"%@\" exceeds maximum allowed size",
                                 bundle: .module,
                                 url.lastPathComponent)
        showError(message)
    }

    func alertBadContentError(_ url: URL) {
        let message =
            // swiftlint:disable:next line_length
            #localized("Invalid file format for \"%@\". Please make sure your file is in a supported format and try again.",
                       bundle: .module,
                       url.lastPathComponent)
        showError(message)
    }

    func parseCapturedPhoto(_ photo: AVCapturePhoto) {
        guard parseTask == nil, importingContexts.value.last == context else { return }
        parseTask = Task { [weak self] in
            guard let self else { return }
            defer { parseTask = nil }
            do {
                guard let data = photo.fileDataRepresentation(),
                      let image = UIImage(data: data) else {
                    throw AuthError.imageParsing(.failedToParseCapturedPhoto)
                }
                let content = try parseImageQRCodeContent(image: image)
                let numberOfImportedEntries = try await entryDataService
                    .importEntries(from: .googleQr(contents: content))
                showCompletion(numberOfImportedEntries)
            } catch {
                showError(#localized("Could not process the image", bundle: .module))
            }
        }
    }

    func showError(_ message: String) {
        let config = AlertConfiguration(title: "An error occurred",
                                        titleBundle: .module,
                                        message: .verbatim(message),
                                        actions: [
                                            .init(title: "OK",
                                                  titleBundle: .module,
                                                  role: .cancel)
                                        ])
        showAlert(config)
    }

    func showAlert(_ config: AlertConfiguration) {
        let alert: AlertDisplay = context.isMainDisplay ? .main(config) : .sheet(config)
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

        case .protonPass:
            "Proton Pass"

        case .authy:
            "Authy"

        case .microsoft:
            "Microsoft Authenticator"
        }
    }

    var authorizedFileExtensions: [UTType] {
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

        case .protonPass:
            [.zip]

        case .googleAuthenticator:
            [.image, .jpeg, .png]

        default:
            []
        }
    }

    func importDestination(content: Data,
                           type: UTType,
                           password: String?,
                           parseImageQRCode: any ParseImageQRCodeContentUseCase) throws -> TwofaImportSource? {
        let textContent: () -> String = {
            String(data: content, encoding: .utf8) ?? ""
        }
        let qrContent: () throws -> String = {
            if let image = CIImage(data: content) {
                try parseImageQRCode(image: image)
            } else {
                ""
            }
        }
        return switch self {
        case .twoFas:
            .twofas(contents: textContent(), password: password)

        case .aegisAuthenticator:
            .aegis(contents: type.toTwofaImportFileType(content: textContent()), password: password)

        case .bitwardenAuthenticator:
            .bitwarden(contents: type.toTwofaImportFileType(content: textContent()))

        case .enteAuth:
            .ente(contents: textContent())

        case .googleAuthenticator:
            try .googleQr(contents: qrContent())

        case .lastPassAuthenticator:
            .lastpass(contents: type.toTwofaImportFileType(content: textContent()))

        case .protonAuthenticator:
            .protonAuthenticator(contents: textContent(), password: password)

        case .protonPass:
            .protonPass(contents: content)

        case .authy, .microsoft:
            nil
        }
    }

    var icon: Image {
        switch self {
        case .googleAuthenticator:
            Image(.googleAuthIcon)

        case .twoFas:
            Image(.twoFAIcon)

        case .aegisAuthenticator:
            Image(.aegisIcon)

        case .bitwardenAuthenticator:
            Image(.bitwardenIcon)

        case .enteAuth:
            Image(.enteIcon)

        case .lastPassAuthenticator:
            Image(.lastpassIcon)

        case .protonAuthenticator:
            Image(.protonAuthIcon)

        case .protonPass:
            Image(.protonPassIcon)

        case .authy:
            Image(.authyIcon)

        case .microsoft:
            Image(.microsoftIcon)
        }
    }

    var canExport: Bool {
        switch self {
        case .authy, .microsoft:
            false

        default:
            true
        }
    }
}

private extension GoogleImportType {
    var title: LocalizedStringKey {
        switch self {
        case .scanQrCode:
            "Scan a QR code"

        case .pickPhoto:
            "Choose one or more Photos"

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
            "Please go to **☰ > Transfer accounts > Export accounts**\n\nThis will create one or more QR codes that you can use here."

        case .twoFas:
            "Please go to **Settings > 2FAS Backup > Export**\n\nThis will create a 2fas file that you can use here."

        case .aegisAuthenticator:
            "Please go to **⋮ > Settings > Import & Export > Export**\n\nThis will create a Json file that you can use here."

        case .bitwardenAuthenticator:
            "Please go to **Settings > Export**\n\nThis will create a Json file that you can use here."

        case .enteAuth:
            "Please go to **☰ > Data > Export codes**\n\nChoose **Plain text**, this will create a txt file that you can use here."

        case .lastPassAuthenticator:
            "Please go to **⚙ > Transfer accounts > Export accounts to file**\n\nThis will create a Json file that you can use here."

        case .protonAuthenticator:
            "Please go to **⚙ > Export**\n\nThis will create a Json file that you can use here."

        case .protonPass:
            "In Proton Pass extension, web or desktop app, go to **☰ > Settings > Export**\n\nMake sure to choose the **zip format without file attachments**.\n\nThis will create a zip file that you can use here."

        case .authy, .microsoft:
            "Unfortunately, \(title) doesn’t currently support exporting data from their app. Consider contacting \(title) to request this feature. \n\nPlease import your data manually for now."
        }
    }
}

// swiftlint:enable line_length

private struct ExplanationView: View {
    @Environment(\.dismiss) private var dismiss
    let option: ImportOption
    let handle: (ImportOption) -> Void

    private var title: String {
        if option.canExport {
            #localized("Import codes from %@", bundle: .module, option.title)
        } else {
            #localized("No export available", bundle: .module)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if #unavailable(iOS 26, macOS 26) {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24)
                            .foregroundStyle(.textNorm.opacity(0.7))
                            .accessibility(label: Text("Close", bundle: .module))
                    }
                    .adaptiveButtonStyle()
                    .padding(16)
                }
            }

            if option.canExport {
                HStack(spacing: 25) {
                    option.icon
                        .resizable()
                        .frame(width: 74, height: 74)
                    Image(.arrow)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32)
                        .accessibilityHidden(true)

                    Image(.protonAuthIcon)
                        .resizable()
                        .frame(width: 74, height: 74)
                        .accessibilityHidden(true)

                    Spacer()
                }
                .frame(height: 170)
                .padding(.horizontal, 32)
            } else {
                HStack {
                    Spacer()
                    ZStack {
                        option.icon
                            .resizable()
                            .frame(width: 96, height: 96, alignment: .center)
                        Image(.importShield)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 433, height: 433)
                            .accessibilityHidden(true)
                    }
                    .frame(width: 225, height: 225)
                    .contentShape(Circle())
                    Spacer()
                }
                .padding(.bottom, 30)
            }

            Text(title) // ignore:missing_bundle
                .dynamicFont(size: 28, textStyle: .title1, weight: .bold)
                .foregroundStyle(.textNorm)
                .multilineTextAlignment(option.canExport ? .leading : .center)
                .frame(maxWidth: .infinity, alignment: option.canExport ? .leading : .center)
                .padding(.horizontal, 32)
            Text(option.explanation, bundle: .module) // ignore:missing_bundle
                .dynamicFont(size: 20, textStyle: .title3)
                .foregroundStyle(.textWeak)
                .multilineTextAlignment(option.canExport ? .leading : .center)
                .frame(maxWidth: .infinity, alignment: option.canExport ? .leading : .center)
                .padding(.horizontal, 32)

            if option.canExport {
                if let url = URL(string: "https://proton.me/support/contact") {
                    Link(destination: url) {
                        Text("Need more help?", bundle: .module)
                            .dynamicFont(size: 20, textStyle: .title3)
                    }
                    .padding(.horizontal, 32)
                }
            }

            Spacer()

            if option.canExport {
                CapsuleButton(title: "Import", textColor: .white, style: .borderedFilled, action: {
                    handle(option)
                    dismiss()
                })
                .padding(.bottom, 45)
                .padding(.horizontal, 32)
            }
        }
        .fullScreenMainBackground()
        .toolbar {
            if #available(iOS 26, macOS 26, *) {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: dismiss.callAsFunction) {
                        Image(systemName: "xmark")
                            .accessibility(label: Text("Close", bundle: .module))
                    }
                }
            }
        }
        .navigationStackEmbeded()
    }
}

private struct ImportView: View {
    @Environment(\.dismiss) private var dismiss
    let handle: (ImportOption) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if #unavailable(iOS 26, macOS 26) {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24)
                            .foregroundStyle(.textNorm.opacity(0.7))
                            .accessibility(label: Text("Close", bundle: .module))
                    }
                    .adaptiveButtonStyle()
                    .padding(16)
                }
            }

            List {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Import codes", bundle: .module)
                        .foregroundStyle(.textNorm)
                        .dynamicFont(size: 28, textStyle: .title1, weight: .bold)

                    Text("Select your current 2FA provider", bundle: .module)
                        .foregroundStyle(.textWeak)
                        .dynamicFont(size: 20, textStyle: .title3)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                ForEach(ImportOption.allCasesSorted, id: \.self) { option in
                    Button {
                        dismiss()
                        handle(option)
                    } label: {
                        HStack(spacing: 12) {
                            option.icon
                                .resizable()
                                .frame(width: 36, height: 36)
                                .cornerRadius(8)
                            Text(verbatim: option.title)
                                .dynamicFont(size: 17, textStyle: .body)
                                .foregroundStyle(.textNorm)
                            Spacer()
                            if !option.canExport {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .resizable()
                                    .frame(width: 22, height: 22)
                                    .foregroundStyle(Color(red: 1, green: 0.83, blue: 0.5))
                                    .accessibilityHidden(true)
                            }
                        }
                        .padding(.vertical, 24)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
            .listStyle(.plain)
            .padding(.horizontal, 32)
        }
        .fullScreenMainBackground()
        .toolbar {
            if #available(iOS 26, macOS 26, *) {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: dismiss.callAsFunction) {
                        Image(systemName: "xmark")
                            .accessibility(label: Text("Close", bundle: .module))
                    }
                }
            }
        }
        .navigationStackEmbeded()
    }
}

private extension ImportOption {
    static var allCasesSorted: [Self] {
        allCases.sorted(by: { $0.title < $1.title })
    }
}

// swiftlint:enable file_length
