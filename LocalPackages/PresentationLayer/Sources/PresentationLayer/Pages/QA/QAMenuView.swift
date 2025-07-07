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
    @State private var showWFullDeleteAlert = false

    var body: some View {
        NavigationStack {
            List {
                onboardingSection
                passBannerSection
                actionsSection
                installationDateSection
            }
            .navigationTitle(Text(verbatim: "QA menu"))
            .toolbar {
                ToolbarItem(placement: toolbarItemPlacement) {
                    Button(action: dismiss.callAsFunction) {
                        Text(verbatim: "Close")
                    }
                }
            }
            .alert(Text(verbatim: "Are you sure you want to delete all entries this cannot be undone?"),
                   isPresented: $showWFullDeleteAlert,
                   actions: {
                       Button("Cancel", role: .cancel) {
                           showWFullDeleteAlert = false
                       }

                       Button { viewModel.deleteAllData() } label: {
                           Text(verbatim: "Delete All")
                       }
                   })
        }
        .tint(Color.success)
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
                showWFullDeleteAlert = true
            } label: {
                Text(verbatim: "Delete all local and remote data")
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
