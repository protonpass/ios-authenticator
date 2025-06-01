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

private struct TextFieldConfig {
    let title: LocalizedStringKey
    let placeholder: LocalizedStringKey
    var isSecret = false
    let binding: Binding<String>
    let field: FocusableField

    #if os(iOS)
    var capitalization: TextInputAutocapitalization = .sentences
    #endif

    func finalBinding(_ focusedField: FocusableField?) -> Binding<String> {
        focusedField == field || !isSecret ?
            binding : .constant(String(repeating: "•", count: binding.wrappedValue.count))
    }
}

private enum FocusableField: Int, Hashable, CaseIterable {
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
                                              field: .name))

                    textField(secretFieldConfig)

                    if viewModel.type == .totp {
                        textField(TextFieldConfig(title: "Issuer (Required)",
                                                  placeholder: "Issuer",
                                                  binding: $viewModel.issuer,
                                                  field: .issuer))
                    }

                    if showAdvanceOptions {
                        if viewModel.type == .totp {
                            pickerSection
                        }
                        segmentedControlSection
                    } else {
                        advancedOptionsButton
                    }
                }
                .onSubmit(focusNextField)
            }
            .padding(.bottom, 10)
            .scrollContentBackground(.hidden)
            .errorMessageAlert($viewModel.errorMessage)
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar { toolbarContent }
                .navigationTitle(Text(viewModel.isEditing ? "Update Entry" : "New Entry",
                                      bundle: .module))
                .animation(.default, value: viewModel.canSave)
                .animation(.default, value: viewModel.type)
                .animation(.default, value: showAdvanceOptions)
                .mainBackground()
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        focusFirstField()
                    }
                }
                .sheetAlertService()
                .onChange(of: viewModel.shouldDismiss) {
                    if viewModel.shouldDismiss {
                        dismiss()
                    }
                }
                .onChange(of: focusedField) { _, _ in
                    viewModel.trimInputs()
                }
        }
        #if os(macOS)
        .frame(minWidth: 800, minHeight: 600)
        #endif
    }

    private func textField(_ config: TextFieldConfig) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(config.title, bundle: .module)
                .foregroundStyle(.textNorm)
                .font(.caption)
                .foregroundStyle(.white)

            TextField(config.placeholder, text: config.finalBinding(focusedField))
                .adaptiveTextFieldStyle()
                .onSubmit(focusNextField)
                .focused($focusedField, equals: config.field)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.textWeak)
                .autocorrectionDisabled(true)
                .frame(minHeight: 25)
            #if os(iOS)
                .textInputAutocapitalization(config.capitalization)
            #endif
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(.inputBackground)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16)
            .inset(by: 0.5)
            .stroke(.inputBorder, lineWidth: 1))
        .padding(.horizontal, 16)
    }

    private var secretFieldConfig: TextFieldConfig {
        #if os(iOS)
        TextFieldConfig(title: "Secret (Required)",
                        placeholder: "Secret",
                        isSecret: true,
                        binding: $viewModel.secret,
                        field: .secret,
                        capitalization: .characters)
        #else
        TextFieldConfig(title: "Secret (Required)",
                        placeholder: "Secret",
                        isSecret: true,
                        binding: $viewModel.secret,
                        field: .secret)
        #endif
    }
}

// MARK: - Advance options

private extension CreateEditEntryView {
    var advancedOptionsButton: some View {
        Button {
            showAdvanceOptions.toggle()
            focusedField = nil
        } label: {
            HStack(alignment: .center, spacing: 8) {
                Text("Advanced options", bundle: .module)
                    .foregroundStyle(.textNorm)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                Spacer()
                Image(systemName: "plus")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .foregroundStyle(.textNorm)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .center)
            .background(.dropdownBackground)
            .cornerRadius(16)
            .padding(.horizontal, 16)
        }
        .adaptiveButtonStyle()
        .impactHaptic()
        .optionShadow()
    }

    var pickerSection: some View {
        VStack {
            pickerFields(title: "Digits",
                         description: { .verbatim("\($0)") },
                         data: viewModel.supportedDigits,
                         binding: $viewModel.digits)
            pickerFields(title: "Time interval",
                         description: { .localized("\($0) seconds", .module) },
                         data: viewModel.supportedPeriod,
                         binding: $viewModel.period)
        }
        .padding(16)
    }

    func pickerFields(title: LocalizedStringKey,
                      description: @escaping (Int) -> TextContent,
                      data: [Int],
                      binding: Binding<Int>) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Text(title, bundle: .module)
                .foregroundStyle(.textNorm)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            Spacer()
            Picker(selection: binding,
                   content: {
                       ForEach(data, id: \.self) { element in
                           Text(description(element)) // ignore:missing_bundle
                               .tag(element)
                       }
                   },
                   label: { Text(verbatim: "") })
                .accentColor(.textNorm)
                .pickerStyle(pickerStyle)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(.dropdownBackground)
        .cornerRadius(16)
        .optionShadow()
    }

    @ViewBuilder
    var segmentedControlSection: some View {
        if viewModel.type == .totp {
            segmentedControlField(title: "ALGORITHM", data: TotpAlgorithm.allCases, binding: $viewModel.algo)
                .impactHaptic()
        }
        segmentedControlField(title: "TYPE", data: TotpType.allCases, binding: $viewModel.type)
            .impactHaptic()
    }

    func segmentedControlField<T: CustomSegmentedControlData>(title: LocalizedStringKey,
                                                              data: [T],
                                                              binding: Binding<T>) -> some View {
        Section {
            CustomSegmentedControl(data: data, selection: binding)
        } header: {
            HStack {
                Text(title, bundle: .module)
                    .foregroundStyle(.textNorm)
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
        return .confirmationAction
        #endif
    }

    var toolbarItemLeadingPlacement: ToolbarItemPlacement {
        #if os(iOS)
        return .topBarLeading
        #else
        return .confirmationAction
        #endif
    }

    var pickerStyle: some PickerStyle {
        #if os(iOS)
        return .automatic
        #else
        return .segmented
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

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        #if os(macOS)
        ToolbarItemGroup(placement: toolbarItemTrailingPlacement) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Text("Close", bundle: .module)
                        .foregroundStyle(.accent)
                        .padding(10)
                }
                .adaptiveButtonStyle()
                .keyboardShortcut(.escape)

                Button {
                    viewModel.save()
                } label: {
                    Text("Save", bundle: .module)
                        .fontWeight(.semibold)
                        .foregroundStyle(.accent)
                        .padding(10)
                }
                .adaptiveButtonStyle()
                .disabled(!viewModel.canSave)
                .opacity(viewModel.canSave ? 1 : 0.4)
                .keyboardShortcut("s")
            }
        }
        #else
        ToolbarItem(placement: toolbarItemLeadingPlacement) {
            Button {
                dismiss()
            } label: {
                Text("Close", bundle: .module)
                    .foregroundStyle(.accent)
                    .padding(10)
            }
            .adaptiveButtonStyle()
        }

        ToolbarItem(placement: toolbarItemTrailingPlacement) {
            Button {
                viewModel.save()
            } label: {
                Text("Save", bundle: .module)
                    .fontWeight(.semibold)
                    .foregroundStyle(.accent)
                    .padding(10)
            }
            .adaptiveButtonStyle()
            .disabled(!viewModel.canSave)
            .opacity(viewModel.canSave ? 1 : 0.4)
        }
        #endif
    }
}

#Preview {
    CreateEditEntryView(entry: nil)
}
