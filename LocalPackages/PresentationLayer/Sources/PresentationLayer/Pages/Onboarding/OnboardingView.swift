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
        .importingService($showImportOptions, onMainDisplay: true)
        .onChange(of: viewModel.biometricEnabled, goNext)
    }
}

private extension OnboardingView {
    @ViewBuilder
    func illustration(height: CGFloat) -> some View {
        VStack(alignment: .center, spacing: 0) {
            VStack {
                Spacer()
                switch viewModel.currentStep {
                case .intro:
                    Image(.introBackground)
                        .overlay(Image("introPreview", bundle: .module)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 256))
                    Spacer()
                        .frame(height: 30)

                case .import:
                    Image("locktree", bundle: .module)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 185)
                    Spacer()
                        .frame(height: 60)

                case .biometric:
                    Image("FaceID", bundle: .module)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 160)
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
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(.textNorm)
                    .padding(.horizontal, 40)

                Text(viewModel.currentStep.description, bundle: .module)
                    .font(.title3)
                    .foregroundStyle(.textWeak)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 8)

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
                }
            }.impactHaptic()

            if supportSkipping {
                CapsuleButton(title: "Skip", textColor: .textNorm, style: .bordered, action: goNext)
                    .impactHaptic()
            } else {
                Image("protonSlogan", bundle: .module)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.textNorm)
                    .frame(height: 52)
                    .frame(maxWidth: 220)
                    .padding(.horizontal)
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
