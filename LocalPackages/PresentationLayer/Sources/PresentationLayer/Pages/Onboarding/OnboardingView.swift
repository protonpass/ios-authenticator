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

public struct OnboardingView: View {
    @State private var viewModel = OnboardingViewModel()
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
        .task { viewModel.getSupportedBiometric() }
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
                    break
                case .biometric:
                    break
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
