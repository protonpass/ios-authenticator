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

import Macro
import Models
import SwiftUI

struct DeleteAllDataView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel = DeleteAllDataViewModel()
    @State private var confirmationText = ""
    @State private var showCompleteAlert = false
    let mode: SyncMode

    private let deleteText = "DELETE"

    private var deletionAllowed: Bool {
        confirmationText == deleteText
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
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 16) {
                Spacer()
                Text("Delete all data", bundle: .module)
                    .foregroundStyle(.textNorm)
                    .dynamicFont(size: 28, textStyle: .title1, weight: .bold)

                Text("Proceed with caution. This action is irreversible.", bundle: .module)
                    .foregroundStyle(.textWeak)
                    .dynamicFont(size: 20, textStyle: .title3)

                Text("Following data will be deleted:", bundle: .module)
                    .foregroundStyle(.textNorm)
                    .dynamicFont(size: 17, textStyle: .body)

                deletionLabel("Data on this device")

//                if mode.contains(.iCloud) {
//                    deletionLabel("Data in iCloud")
//                }

                if mode.contains(.proton) {
                    deletionLabel("Data on Proton servers")
                }

                TextField(#localized("Please type \"%@\" to proceed", bundle: .module, deleteText),
                          text: $confirmationText)
                    .foregroundStyle(.textNorm)
                    .textFieldStyle(.plain)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .dynamicFont(size: 20, textStyle: .title3)
                    .padding(.top)

                Rectangle()
                    .foregroundStyle(.clear)
                    .frame(height: 1)
                    .background(colorScheme == .light ? .black.opacity(0.08) : .white.opacity(0.12))

                deleteButton(viewModel.delete)
                    .padding(.top, 32)

                Spacer()
            }
            .padding()

            Button(action: dismiss.callAsFunction) {
                Image(systemName: "xmark.circle.fill")
                    .frame(width: 24)
                    .foregroundStyle(.textWeak)
            }
            .padding()
        }
    }

    func deletionLabel(_ text: LocalizedStringKey) -> some View {
        Label(text, systemImage: "xmark")
            .foregroundStyle(.error)
            .dynamicFont(size: 17, textStyle: .body)
    }

    func deleteButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("Delete all data", bundle: .module)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(height: 52)
                .background(LinearGradient(stops:
                    [
                        .init(color: Color(red: 1, green: 0.31, blue: 0.31), location: 0),
                        .init(color: Color(red: 0.6, green: 0.19, blue: 0.19), location: 1)
                    ],
                    startPoint: .init(x: 0.5, y: 0),
                    endPoint: .init(x: 0.5, y: 1)))
                .clipShape(.rect(cornerRadius: 26))
                .shadow(color: Color(red: 1, green: 0.37, blue: 0.37).opacity(0.25),
                        radius: 12,
                        x: 0,
                        y: 1)
                .overlay(RoundedRectangle(cornerRadius: 26)
                    .inset(by: 0.25)
                    .stroke(Color.white.opacity(0.12), lineWidth: 0.5))
        }
        .animation(.default, value: deletionAllowed)
        .disabled(!deletionAllowed)
        .opacity(deletionAllowed ? 1 : 0.5)
    }
}
