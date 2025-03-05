//
// CreateEditEntryView.swift
// Proton Authenticator - Created on 10/02/2025.
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

import Models
import SwiftUI

struct CreateEditEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: CreateEditEntryViewModel
    @State private var showAdvanceOptions: Bool = false

    init(entry: EntryUiModel?) {
        _viewModel = .init(wrappedValue: CreateEditEntryViewModel(entry: entry))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name *", text: $viewModel.name)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(.white)

                    SecureField("Secret key *", text: $viewModel.secret)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(.white)
                    if viewModel.type != .steam {
                        TextField("Issuer", text: $viewModel.issuer)
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(.white)
                    }
                } header: {
                    Text("Base information")
                }

                Section {
                    TextField("Note", text: $viewModel.note, axis: .vertical)
                        .foregroundStyle(.white)
                } header: {
                    Text("Additional infos")
                }

                Section {
                    Picker("Type", selection: $viewModel.type) {
                        ForEach(TotpType.allCases) { tokenType in
                            Text(tokenType.rawValue.capitalized)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Type of entry")
                }

                if viewModel.type == .totp {
                    Toggle("Advance options", isOn: $showAdvanceOptions)
                }

                if showAdvanceOptions {
                    if viewModel.type == .totp {
                        Section {
                            Picker("Algorithm", selection: $viewModel.algo) {
                                ForEach(TotpAlgorithm.allCases) { algo in
                                    Text(algo.id.rawValue)
                                        .tag(algo)
                                }
                            }
                            Stepper("Refresh time: **\(Int(viewModel.period))s**",
                                    value: $viewModel.period,
                                    step: 10)
                            Stepper("Number of digits: **\(viewModel.digits)**",
                                    value: $viewModel.digits,
                                    in: 5...9)
                        } header: {
                            Text("Advanced entry settings")
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Manual entry")
            .animation(.default, value: showAdvanceOptions)
            .animation(.default, value: viewModel.canSave)
            .background(.backgroundGradient)
            .toolbar {
                ToolbarItem(placement: toolbarItemPlacement) {
                    Button {
                        viewModel.save()
                        dismiss()
                    } label: {
                        Text("Save")
                            .foregroundStyle(Color.white)
                            .padding(10)
                    }
                    .opacity(viewModel.canSave ? 1 : 0)
                }
            }
            #if os(iOS)
            .toolbarBackground(.backgroundGradient,
                               for: .navigationBar)
            #endif
        }
    }

    private var toolbarItemPlacement: ToolbarItemPlacement {
        #if os(iOS)
        return .topBarTrailing
        #else
        return .automatic
        #endif
    }
}

#Preview {
    CreateEditEntryView(entry: nil)
}
