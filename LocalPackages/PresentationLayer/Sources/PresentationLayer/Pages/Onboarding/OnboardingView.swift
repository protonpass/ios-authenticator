//
// OnboardingView.swift
// Proton Authenticator - Created on 19/03/2025.
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

import SwiftUI

private enum ImportOption: Sendable, CaseIterable {
    case googleAuthenticator, twoFas, aegisAuthenticator
    case bitwardenAuthenticator, enteAuth, lastPassAuthenticator
    case protonPass, protonAuthenticator
}

private enum ImportFromGoogleOption: Sendable, CaseIterable {
    case scanQrCode, pickPhoto, importFromFiles
}

public struct OnboardingView: View {
    @State private var viewModel = OnboardingViewModel()
    @State private var showImportOptions = false
    @State private var showImportFromGoogleOptions = false
    let onFinish: () -> Void

    public init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }

    public var body: some View {
        ZStack {
            Color.clear
                .mainBackground()
                .ignoresSafeArea()

            mainContent
        }
        .tint(.purpleInteraction)
        .task { viewModel.getSupportedBiometric() }
        .importOptionsDialog(isPresented: $showImportOptions, onSelect: handle)
        .importFromGoogleOptionsDialog(isPresented: $showImportFromGoogleOptions,
                                       onSelect: handle)
        .onChange(of: viewModel.biometricEnabled, goNext)
    }
}

private extension OnboardingView {
    var mainContent: some View {
        VStack {
            VStack(alignment: .center) {
                Spacer()

                Spacer()

                Text(viewModel.currentStep.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(.textNorm)

                Text(viewModel.currentStep.description)
                    .font(.headline)
                    .foregroundStyle(.textNorm)

                Spacer()

                switch viewModel.currentStep {
                case .intro:
                    actions(supportSkipping: false)
                case .import:
                    actions()
                case .biometric:
                    actions()
                }
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    func actions(supportSkipping: Bool = true) -> some View {
        VStack {
            CapsuleButton(title: viewModel.currentStep.primaryActionTitle,
                          style: .borderedFilled) {
                switch viewModel.currentStep {
                case .intro:
                    goNext()
                case .import:
                    showImportOptions.toggle()
                case .biometric:
                    viewModel.enableBiometric()
                }
            }

            if supportSkipping {
                CapsuleButton(title: "Skip", style: .bordered, action: goNext)
            } else {
                Image("protonSlogan", bundle: .module)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.textNorm)
                    .frame(maxWidth: 220)
                    .padding(.horizontal)
            }
        }
    }

    func goNext() {
        withAnimation {
            if !viewModel.goNext() {
                onFinish()
            }
        }
    }

    func handle(_ option: ImportOption) {
        switch option {
        case .googleAuthenticator:
            showImportFromGoogleOptions.toggle()
        default:
            break
        }
    }

    func handle(_ option: ImportFromGoogleOption) {
        print(option)
    }
}

private extension View {
    func importOptionsDialog(isPresented: Binding<Bool>,
                             onSelect: @escaping (ImportOption) -> Void) -> some View {
        confirmationDialog("Select your prodiver",
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
                                       onSelect: @escaping (ImportFromGoogleOption) -> Void) -> some View {
        confirmationDialog("Select your prodiver",
                           isPresented: isPresented,
                           titleVisibility: .hidden) {
            ForEach(ImportFromGoogleOption.allCases, id: \.self) { option in
                Button(action: { onSelect(option) }, label: {
                    Text(option.title)
                })
            }
        }
    }
}

private extension OnboardStep {
    var title: LocalizedStringKey {
        switch self {
        case .intro:
            "Security in every code"
        case .import:
            "Import codes"
        case .biometric:
            "Protect your data"
        }
    }

    var description: LocalizedStringKey {
        switch self {
        case .intro:
            "Use two-factor authentication to safeguard your accounts."
        case .import:
            "Bring your security with you.\nTransfer your data to stay protected."
        case let .biometric(type):
            switch type {
            case .faceID:
                "Add an extra layer of security with Face ID."
            case .touchID:
                "Add an extra layer of security with Touch ID."
            case .opticID:
                "Add an extra layer of security with Optic ID."
            }
        }
    }

    var primaryActionTitle: LocalizedStringKey {
        switch self {
        case .intro:
            "Get started"
        case .import:
            "Import"
        case let .biometric(type):
            switch type {
            case .faceID:
                "Enable Face ID"
            case .touchID:
                "Enable Touch ID"
            case .opticID:
                "Enable Optic ID"
            }
        }
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
        case .protonPass:
            "Proton Pass"
        case .protonAuthenticator:
            "Proton Authenticator"
        }
    }
}

private extension ImportFromGoogleOption {
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
