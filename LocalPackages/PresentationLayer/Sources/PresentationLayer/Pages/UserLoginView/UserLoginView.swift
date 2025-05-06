//
//
// UserLoginView.swift
// Proton Authenticator - Created on 25/04/2025.
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

import SwiftUI

struct UserLoginView: View {
    @Environment(\.dismiss) private var dismiss

    private let onAction: (Bool) -> Void

    init(onAction: @escaping (_ signUp: Bool) -> Void) {
        self.onAction = onAction
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(.loginIcon)
                .resizable()
                .scaledToFit()
            Spacer()

            VStack(spacing: 8) {
                Text("Device sync", bundle: .module)
                    .font(.title)
                    .fontWeight(.bold)
                    .kerning(0.392)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.textNorm)
                    .frame(maxWidth: .infinity, alignment: .top)
                Text("Proton account is required to enable end-to-end encrypted sync between devices.",
                     bundle: .module)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.textWeak)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .opacity(0.9)
            }

            Spacer()

            VStack(spacing: DesignConstant.padding) {
                CapsuleButton(title: "Create a free account",
                              textColor: .white,
                              style: .borderedFilled) {
                    onAction(true)
                }
                #if os(iOS)
                .impactHaptic()
                #endif

                CapsuleButton(title: "Sign in", textColor: .textNorm, style: .bordered, action: {
                    onAction(false)
                })
                #if os(iOS)
                .impactHaptic()
                #endif

                Image(.protonPrivacy)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 20)
                    .padding(.top, 16)
            }

            Spacer()
        }
        .padding(.horizontal, 40)
        .toolbar {
            ToolbarItem(placement: toolbarTrailingItemPlacement) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24)
                        .foregroundStyle(.textNorm.opacity(0.7))
                }
                .adaptiveButtonStyle()
            }
        }
        .toastDisplay()
        .fullScreenMainBackground()
        .sheetAlertService()
    }

    private var toolbarTrailingItemPlacement: ToolbarItemPlacement {
        #if os(iOS)
        return .topBarTrailing
        #else
        return .automatic
        #endif
    }
}

#Preview {
    UserLoginView(onAction: { _ in })
}
