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

    @State private var viewModel = UserLoginViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()
                Image(.loginIcon)
                    .resizable()
                    .scaledToFit()
//                    .padding(.horizontal, 104)
                Spacer()

                VStack(spacing: 8) {
                    Text("Device sync")
                        .font(Font.custom("SF Pro", size: 28, relativeTo: .body)
                            .weight(.bold))
                        .kerning(0.392)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.textNorm)
                        .frame(maxWidth: .infinity, alignment: .top)
                    Text("Proton account is required to enable end-to-end encrypted sync between devices.")
                        .font(Font.custom("SF Pro", size: 20, relativeTo: .body))
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
                        viewModel.beginAddAccountFlow(isSigningUp: true, rootViewController: self)
//                        switch viewModel.currentStep {
//                        case .intro:
//                            goNext()
//                        case .import:
//                            showImportOptions.toggle()
//                        case .biometric:
//                            viewModel.enableBiometric()
//                        }
                    }
                    #if os(iOS)
                    .impactHaptic()
                    #endif

                    CapsuleButton(title: "Sign in", textColor: .textNorm, style: .bordered, action: {
                        viewModel.beginAddAccountFlow(isSigningUp: false, rootViewController: self)
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
//                .padding(.horizontal, 40)
//                .padding(.bottom)

                Spacer()

                //            List {
                //                ForEach(viewModel.logs) { log in
                //                    Text(verbatim: log.description)
                //                        .listRowBackground(Color.clear)
                //                }
                //            }
                //            .listStyle(.plain)
            }
            .padding(.horizontal, 40)
            .toolbar {
//                ToolbarItem(placement: toolbarItemPlacement) {
//                    Button {
//                        dismiss()
//                    } label: {
//                        Text("Close", bundle: .module)
//                            .foregroundStyle(.purpleInteraction)
//                    }
//                    .adaptiveButtonStyle()
//                }
//
                ToolbarItem(placement: toolbarTrailingItemPlacement) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .resizable()
                            .scaledToFit()
//                            .padding(DesignConstant.padding)
                            .frame(width: 24)
                            .foregroundStyle(.textNorm.opacity(0.7))
                    }
                    .adaptiveButtonStyle()
                }
            }
//            .scrollContentBackground(.hidden)
//            #if os(iOS)
//                .listSectionSpacing(DesignConstant.padding * 2)
//                .navigationBarTitleDisplayMode(.inline)
//            #endif
            .toastDisplay()
            .fullScreenMainBackground()
            .sheetAlertService()
        }
        #if os(macOS)
        .frame(minWidth: 800, minHeight: 600)
        #endif
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
    UserLoginView()
}
