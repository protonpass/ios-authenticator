//
// QAMenuView.swift
// Proton Authenticator - Created on 15/02/2025.
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

struct QAMenuView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = QAMenuViewModel()
    @State private var showFullDeleteAlert = false

    var body: some View {
        NavigationStack {
            List {
                onboardingSection
                fullBackup
                passBannerSection
                actionsSection
                installationDateSection
            }
            .showSpinner(viewModel.isLoading)
            .navigationTitle(Text(verbatim: "QA menu"))
            .toolbar {
                ToolbarItem(placement: toolbarItemPlacement) {
                    Button(action: dismiss.callAsFunction) {
                        Text(verbatim: "Close")
                    }
                }
            }
            .alert(Text(verbatim: "Are you sure you want to delete all data this cannot be undone?"),
                   isPresented: $showFullDeleteAlert,
                   actions: {
                       Button("Cancel", role: .cancel) {
                           showFullDeleteAlert = false
                       }

                       Button(role: .destructive, action: viewModel.deleteAllData) {
                           Text(verbatim: "Delete All")
                       }
                   })
        }
    }

    private var toolbarItemPlacement: ToolbarItemPlacement {
        #if os(iOS)
        return .topBarLeading
        #else
        return .navigation
        #endif
    }
}

private extension QAMenuView {
    var onboardingSection: some View {
        Section(content: {
            Toggle(isOn: $viewModel.onboarded, label: { Text(verbatim: "Onboarded") })
        }, header: {
            Text(verbatim: "Onboarding")
        })
    }

    var fullBackup: some View {
        Section(content: {
            Toggle(isOn: $viewModel.fullBackupActivated, label: { Text(verbatim: "New backup section") })
        }, header: {
            Text(verbatim: "Bach up options")
        })
    }

    var passBannerSection: some View {
        Section(content: {
            Toggle(isOn: $viewModel.displayPassBanner,
                   label: { Text(verbatim: "Display Pass Banner") })
        }, header: {
            Text(verbatim: "Pass Banner")
        })
    }

    var actionsSection: some View {
        Section(content: {
            Button {
                showFullDeleteAlert = true
            } label: {
                Text(verbatim: "Remove all data (iCloud, local and remote)")
            }
        }, header: {
            Text(verbatim: "Actions")
        })
    }

    var installationDateSection: some View {
        Section(content: {
            DatePicker(selection: $viewModel.installationDate,
                       in: ...Date.now,
                       displayedComponents: .date) {
                Text(verbatim: "Installation date")
            }
        }, header: {
            Text(verbatim: "Installation date")
        })
        .onChange(of: viewModel.installationDate) { _, newDate in
            viewModel.updateInstallationTimestamp(newDate)
        }
    }
}
