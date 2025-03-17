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

import DataLayer
import Models
import SwiftUI

private struct TextFieldConfig {
    let title: LocalizedStringKey
    let placeholder: LocalizedStringKey
    let binding: Binding<String>
    let focusField: FocusableField
    var isSecure = false
}

private enum FocusableField: Hashable, CaseIterable {
    case name, secret, issuer
}

struct CreateEditEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: CreateEditEntryViewModel
    @State private var showAdvanceOptions = false
    @FocusState private var focusedField: FocusableField?

    init(entry: EntryUiModel?) {
        _viewModel = .init(wrappedValue: CreateEditEntryViewModel(entry: entry))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    textField(TextFieldConfig(title: "Title (Required)",
                                              placeholder: "Title",
                                              binding: $viewModel.name,
                                              focusField: .name))
                    textField(TextFieldConfig(title: "Secret (Required)",
                                              placeholder: "Secret",
                                              binding: $viewModel.secret,
                                              focusField: .secret,
                                              isSecure: true))

                    if viewModel.type == .totp {
                        textField(TextFieldConfig(title: "Issuer (Required)",
                                                  placeholder: "Issuer",
                                                  binding: $viewModel.issuer,
                                                  focusField: .issuer))
                    }
                }

                if showAdvanceOptions {
                    advancedOptions
                } else {
                    Button { showAdvanceOptions.toggle() } label: {
                        HStack(alignment: .center, spacing: 8) {
                            Text("Advanced options")
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                            Spacer()
                            Image(systemName: "plus")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 18, height: 18)
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .background(.white.opacity(0.12))
                        .cornerRadius(16)
                        .padding(.horizontal, 16)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(viewModel.isEditing ? "Manual entry" : "New entry")
            .animation(.default, value: viewModel.canSave)
            .animation(.default, value: viewModel.type)
            .background(.backgroundGradient)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    focusFirstField()
                }
            }
            .onSubmit(focusNextField)
            .toolbar {
                ToolbarItem(placement: toolbarItemLeadingPlacement) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Close")
                            .foregroundStyle(Color.purpleInteraction)
                            .padding(10)
                    }
                }

                ToolbarItem(placement: toolbarItemTrailingPlacement) {
                    Button {
                        viewModel.save()
                        dismiss()
                    } label: {
                        Text("Save")
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.purpleInteraction)
                            .padding(10)
                    }
                    .disabled(!viewModel.canSave)
                    .opacity(viewModel.canSave ? 1 : 0.4)
                }
            }
            .alert(viewModel.alertService.alert?.title ?? "Unknown",
                   isPresented: $viewModel.alertService.showSheetAlert,
                   presenting: viewModel.alertService.alert,
                   actions: { display in
                       display.buildActions
                   },
                   message: { display in
                       Text(verbatim: display.message ?? "")
                   })
            #if os(iOS)
                   .toolbarBackground(.backgroundGradient, for: .navigationBar)
            #endif
        }
    }

    private func textField(_ config: TextFieldConfig) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(config.title)
                .font(.caption)
                .foregroundStyle(.white)
            if config.isSecure {
                SecureField(config.placeholder, text: config.binding)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.white)
                    .autocorrectionDisabled(true)
                    .focused($focusedField, equals: .secret)
            } else {
                TextField(config.placeholder, text: config.binding)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.white)
                    .focused($focusedField, equals: config.focusField)
                    .autocorrectionDisabled(true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(.black.opacity(0.5))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16)
            .inset(by: 0.5)
            .stroke(.white.opacity(0.12), lineWidth: 1))
        .padding(.horizontal, 16)
    }
}

// MARK: - Advance options

private extension CreateEditEntryView {
    @ViewBuilder
    var advancedOptions: some View {
        if viewModel.type == .totp {
            pickerSection
        }
        segmentedControlSection
    }

    var pickerSection: some View {
        VStack {
            pickerFields(title: "Digits",
                         data: viewModel.supportedDigits,
                         binding: $viewModel.digits)
            pickerFields(title: "Time interval",
                         data: viewModel.supportedPeriod,
                         binding: $viewModel.period)
        }
        .padding(16)
    }

    func pickerFields(title: LocalizedStringKey, data: [Int], binding: Binding<Int>) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Text(title)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            Spacer()
            Picker(title, selection: binding) {
                ForEach(data, id: \.self) { element in
                    Text(verbatim: "\(element)")
                        .tag(element)
                }
            }
            .accentColor(.white)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(.white.opacity(0.12))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.11), radius: 2, x: 0, y: 2)
    }

    @ViewBuilder
    var segmentedControlSection: some View {
        if viewModel.type == .totp {
            segmentedControlField(title: "ALGORITHM", data: TotpAlgorithm.allCases, binding: $viewModel.algo)
        }
        segmentedControlField(title: "TYPE", data: TotpType.allCases, binding: $viewModel.type)
    }

    func segmentedControlField<T: CustomSegmentedControlData>(title: LocalizedStringKey,
                                                              data: [T],
                                                              binding: Binding<T>) -> some View {
        Section {
            CustomSegmentedControl(data: data, selection: binding)
        } header: {
            HStack {
                Text(title)
                    .foregroundStyle(Color.textNorm)
                    .opacity(0.7)
                    .padding(.leading, 16)
                Spacer()
            }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Focus and button placements

private extension CreateEditEntryView {
    var toolbarItemTrailingPlacement: ToolbarItemPlacement {
        #if os(iOS)
        return .topBarTrailing
        #else
        return .automatic
        #endif
    }

    var toolbarItemLeadingPlacement: ToolbarItemPlacement {
        #if os(iOS)
        return .topBarLeading
        #else
        return .automatic
        #endif
    }

    func focusFirstField() {
        focusedField = FocusableField.allCases.first
    }

    func focusNextField() {
        switch focusedField {
        case .name:
            focusedField = .secret
        case .secret:
            if viewModel.type == .totp {
                focusedField = .issuer
            } else {
                focusedField = nil
            }
        case .issuer:
            focusedField = nil
        case .none:
            break
        }
    }
}

#Preview {
    CreateEditEntryView(entry: nil)
}
