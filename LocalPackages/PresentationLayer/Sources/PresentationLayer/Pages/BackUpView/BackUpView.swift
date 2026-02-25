//
//
// BackUpView.swift
// Proton Authenticator - Created on 18/07/2025.
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

import CommonUtilities
import Macro
import Models
import SwiftUI
import UniformTypeIdentifiers

struct BackUpView: View {
    @State private var viewModel = BackUpViewModel()
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        mainContent
            .task {
                viewModel.loadData()
            }
            .fileImporter(isPresented: $viewModel.showFolderPicker,
                          allowedContentTypes: [.folder],
                          onCompletion: viewModel.handleFolderSelection)
            .showSpinner(viewModel.loading)
            .padding(.bottom, 10)
            .scrollContentBackground(.hidden)
            .errorMessageAlert($viewModel.errorMessage)
            .sheetAlertService()
            .alert("Backup data protection", isPresented: $viewModel.showPasswordAlert) {
                SecureField("Password", text: $viewModel.password)
                    .autocorrectionDisabled()
                    .textContentType(.password)
                    .textInputAutocapitalization(.never)
                SecureField("Confirm password", text: $viewModel.confirmedPassword)
                    .autocorrectionDisabled()
                    .textContentType(.password)
                    .textInputAutocapitalization(.never)
                Button { viewModel.savePassword() } label: {
                    Text("Save password", bundle: .module)
                }
                .disabled(!viewModel.passwordSavable)
                Button("Cancel", role: .cancel) {
                    viewModel.password = ""
                    viewModel.confirmedPassword = ""
                }
            } message: {
                Text("Set a password to protect backup files.", bundle: .module)
            }
            .alert("Choose backup destination", isPresented: $viewModel.showDestinationAlert) {
                Button { viewModel.useDefaultDestination() } label: {
                    Text("Use default folder", bundle: .module)
                }
                Button { viewModel.chooseCustomDestination() } label: {
                    Text("Choose folder", bundle: .module)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                // swiftlint:disable:next line_length
                Text("Backups will be saved to a folder of your choice. The default folder \"Proton Authenticator Backups\" will be created in your app's documents and is accessible via the Files app.",
                     bundle: .module)
            }
            .alert("Please enter the password used to encrypt this backup.",
                   isPresented: $viewModel.passwordProtectionFile.mappedToBool(),
                   presenting: viewModel.passwordProtectionFile) { backup in
                SecureField("Password", text: $viewModel.password)
                    .autocorrectionDisabled()
                    .textContentType(.oneTimeCode)
                    .textInputAutocapitalization(.never)
                Button { viewModel.loadPasswordProtectedBackup(backup: backup) } label: {
                    Text("Decrypt the backup", bundle: .module)
                }
                Button("Cancel", role: .cancel) {
                    viewModel.password = ""
                }
            }

        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .toolbar { toolbarContent }
            .navigationTitle(Text("Backups", bundle: .module))
            .fullScreenMainBackground()
    }

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    private var settingsBorder: Color {
        (isDarkMode ? Color.white : .black).opacity(0.12)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        #if os(iOS)
        if viewModel.backupActivated {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.backup()
                } label: {
                    Text("Backup now", bundle: .module)
                        .fontWeight(.semibold)
                        .foregroundStyle(.accent)
                        .padding(10)
                }
                .adaptiveButtonStyle()
            }
        }
        #endif
    }
}

// MARK: - Views elements

private extension BackUpView {
    var mainContent: some View {
        List {
            setupSection
            backupSection
        }
        .scrollBounceBehavior(.basedOnSize)
        .listStyle(.insetGrouped)
        .frame(maxHeight: .infinity)
        .animation(.default, value: viewModel.backupActivated)
    }

    var setupSection: some View {
        section("SETUP") {
            SettingRow(title: .localized("Automatic Backup", .module),
                       trailingMode: .toggle(isOn: viewModel.backupActivated,
                                             onToggle: viewModel.toggleBackup))
            if viewModel.backupActivated {
                SettingDivider()
                Button { viewModel.changeFolder() } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        row(title: .localized("Folder location", .module), imageName: "chevron.right")
                        if let folderName = viewModel.folderDisplayName {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: folderName) // ignore:missing_bundle
                                    .dynamicFont(size: 13, textStyle: .body)
                                    .foregroundStyle(.textWeak)
                                if let path = viewModel.folderPath {
                                    Text(verbatim: path) // ignore:missing_bundle
                                        .dynamicFont(size: 11, textStyle: .caption1)
                                        .foregroundStyle(.textWeak.opacity(0.7))
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                            }
                            .padding(.bottom, 8)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    var backupSection: some View {
        if viewModel.showBackup {
            section("BACKUPS") {
                ForEach(viewModel.backups) { backup in
                    Button { viewModel.load(backup: backup) } label: {
                        row(title: .localized("Backup from \(backup.displayedDate)", .module))
                    }
                    .buttonStyle(.plain)
                }
            }
            VStack {
                Text("Only the last 5 backups are kept.", bundle: .module)
                    .frame(maxWidth: .infinity, alignment: .center)
                if let displayedDate = viewModel.backups.first?.displayedDate {
                    Text("Last backup: \(displayedDate)", bundle: .module)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .dynamicFont(size: 13, textStyle: .body)
            .foregroundStyle(.textWeak)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }
}

// MARK: - Utils

private extension BackUpView {
    @ViewBuilder
    func section(_ title: LocalizedStringKey?, @ViewBuilder content: () -> some View) -> some View {
        if #available(iOS 26, macOS 26, *) {
            Section(content: {
                content()
            }, header: {
                if let title {
                    Text(title, bundle: .module)
                        .dynamicFont(size: 13, textStyle: .footnote)
                }
            })
        } else {
            VStack(spacing: DesignConstant.padding) {
                if let title {
                    Text(title, bundle: .module)
                        .dynamicFont(size: 13, textStyle: .footnote)
                        .foregroundStyle(.textWeak)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, DesignConstant.padding)
                }

                VStack(alignment: .leading, spacing: 0) {
                    content()
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .background(isDarkMode ? .white.opacity(0.08) : .white)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .inset(by: 0.5)
                    .stroke(settingsBorder, lineWidth: 1))
            }
            .plainListRow()
            .padding(.horizontal, DesignConstant.padding)
            .padding(.top, DesignConstant.padding * 2)
        }
    }

    func row(title: TextContent,
             imageName: String = "clock.arrow.trianglehead.counterclockwise.rotate.90") -> some View {
        HStack(spacing: 0) {
            Text(title) // ignore:missing_bundle
                .foregroundStyle(.textNorm)
                .dynamicFont(size: 17, textStyle: .body)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            Image(systemName: imageName)
                .foregroundStyle(.textNorm)
        }
        .contentShape(.rect)
    }
}

#Preview {
    BackUpView()
}
