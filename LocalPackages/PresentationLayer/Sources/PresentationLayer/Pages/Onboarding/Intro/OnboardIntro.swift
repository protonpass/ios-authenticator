//
// OnboardIntro.swift
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

struct OnboardIntro: View {
    let onNext: () -> Void

    var body: some View {
        ZStack {
            Color.clear
                .mainBackground()
                .ignoresSafeArea()

            VStack(alignment: .center) {
                Spacer()

                Spacer()

                OnboardingText(.title("Security in every code"))
                    .padding(.horizontal)

                OnboardingText(.description("Use two-factor authentication to safeguard your accounts."))
                    .padding(.horizontal)

                Spacer()

                CapsuleButton(title: "Get started", action: onNext)
                    .padding()

                Image("protonSlogan", bundle: .module)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.textNorm)
                    .frame(maxWidth: 220)
                    .padding(.horizontal)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
