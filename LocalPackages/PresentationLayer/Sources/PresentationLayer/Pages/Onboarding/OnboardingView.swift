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

import CommonUtilities
import Lottie
import Models
import SwiftUI

public struct OnboardingView: View {
    @State private var viewModel = OnboardingViewModel()
    @State private var showImportOptions = false

    public init() {}

    public var body: some View {
        GeometryReader { proxy in
            let illustrationHeight = proxy.size.height * 0.55
            illustration(height: illustrationHeight)
            textAndButton(illustrationHeight: illustrationHeight)
        }
        .fullScreenMainBackground()
        .tint(.purpleInteraction)
        .task { viewModel.getSupportedBiometric() }
        .importingService($showImportOptions,
                          context: .onboarding,
                          onComplete: goNext)
        .onChange(of: viewModel.biometricEnabled, goNext)
        .sheet(isPresented: $viewModel.showBackUpView, onDismiss: goNext) {
            NavigationStack {
                BackUpView()
            }
        }
    }
}

private extension OnboardingView {
    func illustration(height: CGFloat) -> some View {
        VStack(alignment: .center, spacing: 0) {
            VStack {
                Spacer()
                switch viewModel.currentStep {
                case .intro:
                    Image(ProcessInfo().isiOSAppOnMac ? .introPreviewDesktop : .introPreview)
                        .resizable()
                        .scaledToFill()
                        .if(!ProcessInfo().isiOSAppOnMac) { view in
                            view
                                .offset(y: AppConstants.isPhone ? height / 8 : (-height / 8))
                        }

                case .import:
                    LottieView(animation: .named("LockTree", bundle: .module))
                        .playing(loopMode: .playOnce)
                        .frame(maxWidth: 185)
                    Spacer()
                        .frame(height: 60)

                case .biometric:
                    LottieView(animation: .named("FaceID", bundle: .module))
                        .playing(loopMode: .playOnce)
                        .frame(maxWidth: 260)
                        .offset(y: AppConstants.isPhone ? height / 10 : 0)

                case .backup:
                    Image(.backupsOnboarding)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 185)
                    Spacer()
                        .frame(height: 60)
                }
            }
            .frame(height: height)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    func textAndButton(illustrationHeight: CGFloat) -> some View {
        VStack {
            VStack(alignment: .center, spacing: 0) {
                Spacer(minLength: illustrationHeight)

                Text(viewModel.currentStep.title, bundle: .module)
                    .dynamicFont(size: 28, textStyle: .title1, weight: .bold)
                    .fontWeight(.bold)
                    .foregroundStyle(.textNorm)
                    .padding(.horizontal, 40)

                Text(viewModel.currentStep.description, bundle: .module)
                    .dynamicFont(size: 20, textStyle: .title3)
                    .foregroundStyle(.textWeak)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 8)

                Spacer()

                switch viewModel.currentStep {
                case .intro:
                    actions(supportSkipping: false)

                case .backup, .biometric, .import:
                    actions()
                }
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    func actions(supportSkipping: Bool = true) -> some View {
        VStack(spacing: 16) {
            CapsuleButton(title: viewModel.currentStep.primaryActionTitle,
                          textColor: .white,
                          style: .borderedFilled) {
                switch viewModel.currentStep {
                case .intro:
                    goNext()

                case .import:
                    showImportOptions.toggle()

                case .biometric:
                    viewModel.enableBiometric()

                case .backup:
                    viewModel.enableBackup()
                }
            }
            .impactHaptic()

            if supportSkipping {
                CapsuleButton(title: "Skip", textColor: .textNorm, style: .bordered, action: goNext)
                    .impactHaptic()
            } else {
                Image(.protonSlogan)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.textNorm)
                    .frame(height: 52)
                    .frame(maxWidth: 220)
                    .padding(.horizontal)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 40)
        .padding(.bottom)
    }

    func goNext() {
        withAnimation {
            if !viewModel.goNext() {
                viewModel.finishOnboarding()
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

        case .backup:
            "Keep your data safe"
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

        case .backup:
            "Set up automatic encrypted backups to a folder of your choice."
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

        case .backup:
            "Set up backups"
        }
    }
}
