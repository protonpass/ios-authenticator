//
// DeleteAllDataView.swift
// Proton Authenticator - Created on 8/09/2025.
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

struct DeleteAllDataView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel = DeleteAllDataViewModel()
    @State private var confirmationText = ""
    @State private var showCompleteAlert = false
    let config: SyncConfiguration

    private var deletionAllowed: Bool {
        confirmationText == "DELETE"
    }

    var body: some View {
        ZStack {
            Color.clear
                .mainBackground()
                .ignoresSafeArea()

            switch viewModel.state {
            case .idle:
                idle

            case .deleting:
                Label(title: {
                    Text("Deleting all your data", bundle: .module)
                        .foregroundStyle(.textNorm)
                }, icon: {
                    ProgressView()
                })

            case .deleted:
                EmptyView()

            case let .error(error):
                RetryableErrorView(tintColor: .accent,
                                   error: error,
                                   onRetry: viewModel.delete)
            }
        }
        .animation(.default, value: viewModel.state)
        .onChange(of: viewModel.state) { _, newValue in
            if newValue == .deleted {
                showCompleteAlert.toggle()
            }
        }
        .alert("Done",
               isPresented: $showCompleteAlert,
               actions: {
                   Button("Close", action: dismiss.callAsFunction)
               }, message: {
                   Text("All your data is deleted", bundle: .module)
               })
    }
}

private extension DeleteAllDataView {
    var idle: some View {
        VStack(alignment: .center) {
            HStack {
                Spacer()
                Button(action: dismiss.callAsFunction) {
                    Image(systemName: "xmark.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24)
                        .foregroundStyle(.textNorm.opacity(0.7))
                }
                .adaptiveButtonStyle()
            }
            .frame(height: 60)
            .padding(.bottom, 36)

            Text("Delete all data", bundle: .module)
                .foregroundStyle(.textNorm)
                .dynamicFont(size: 28, textStyle: .title1, weight: .bold)

            Text(config.title, bundle: .module)
                .foregroundStyle(.textWeak)
                .dynamicFont(size: 20, textStyle: .title3)
                .padding(.top, 8)
                .padding(.bottom, 32)

            TextField(text: $confirmationText, label: { EmptyView() })
                .foregroundStyle(.textNorm)
                .textFieldStyle(.plain)
                .textInputAutocapitalization(.characters)
                .dynamicFont(size: 20, textStyle: .title3)

            Rectangle()
                .foregroundStyle(.clear)
                .frame(height: 1)
                .background(colorScheme == .light ? .black.opacity(0.08) : .white.opacity(0.12))

            Button(action: viewModel.delete) {
                Text("Delete all data", bundle: .module)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
                    .background(.red)
                    .shadow(color: Color(red: 0.6, green: 0.37, blue: 1).opacity(0.25),
                            radius: 12,
                            x: 0,
                            y: 1)
                    .overlay(Capsule()
                        .inset(by: 0.25)
                        .stroke(colorScheme == .dark ? .white.opacity(0.12) : .black.opacity(0.20),
                                lineWidth: 0.5))
                    .clipShape(.capsule)
            }
            .animation(.default, value: deletionAllowed)
            .disabled(!deletionAllowed)
            .opacity(deletionAllowed ? 1 : 0.5)
            .padding(.top, 32)

            Spacer()
        }
        .padding()
        .tint(.red)
    }
}

private extension SyncConfiguration {
    var title: LocalizedStringKey {
        switch self {
        case .local:
            "You're about to delete all data on this device. Please type \"DELETE\" to proceed."
        case .iCloud:
            "You're about to delete all data on this device and iCloud. Please type \"DELETE\" to proceed."
        case .iCloudAndProton:
            // swiftlint:disable:next line_length
            "You're about to delete all data on this device, iCloud and Proton servers. Please type \"DELETE\" to proceed."
        }
    }
}
