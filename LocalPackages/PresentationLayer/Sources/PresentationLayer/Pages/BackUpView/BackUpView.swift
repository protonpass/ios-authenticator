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
            .alert("Backup restoration",
                   isPresented: $viewModel.selectedBackup.mappedToBool(),
                   presenting: viewModel.selectedBackup) { backup in
                Button { viewModel.load(backup: backup) } label: {
                    Text("Restore", bundle: .module)
                }
                Button("Cancel", role: .cancel) {
                    viewModel.selectedBackup = nil
                }
            } message: { backup in
                Text("Are you sure you want to restore the backup named \(backup.name)?", bundle: .module)
            }
            .alert("Delete backup",
                   isPresented: $viewModel.backupToDelete.mappedToBool(),
                   presenting: viewModel.backupToDelete) { _ in
                Button("Delete", role: .destructive) { viewModel.confirmDeleteBackup() }
                Button("Cancel", role: .cancel) { viewModel.backupToDelete = nil }
            } message: { backup in
                Text("Are you sure you want to delete the backup \"\(backup.name)\"? This cannot be undone.",
                     bundle: .module)
            }

        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .toolbar { toolbarContent }
            .navigationTitle(Text("Backups", bundle: .module))
            .fullScreenMainBackground()
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
        SettingsSectionContainer(title: "BACKUP SETTINGS") {
            SettingRow(title: .localized("Automatic Backup", .module),
                       trailingMode: .toggle(isOn: viewModel.backupActivated,
                                             onToggle: viewModel.toggleBackup))
            if viewModel.backupActivated {
                SettingDivider()
                Button { viewModel.showFolderPicker = true } label: {
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
                    .paddingIfNotLiquidGlass()
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    var backupSection: some View {
        if viewModel.showBackup {
            SettingsSectionContainer(title: "BACKUPS") {
                ForEach(viewModel.backups) { backup in
                    Button { viewModel.selectedBackup = backup } label: {
                        row(title: .localized("Backup from \(backup.displayedDate)", .module))
                    }
                    .buttonStyle(.plain)
                    .paddingIfNotLiquidGlass()
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            viewModel.deleteBackup(backup)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
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
