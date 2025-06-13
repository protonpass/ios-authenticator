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

    var body: some View {
        NavigationStack {
            List {
                syncSection
                mockEntriesSection
                onboardingSection
                passBannerSection
            }
            .animation(.default, value: viewModel.qaService.showMockEntries)
            .navigationTitle(Text(verbatim: "QA menu"))
            .toolbar {
                ToolbarItem(placement: toolbarItemPlacement) {
                    Button(action: dismiss.callAsFunction) {
                        Text(verbatim: "Close")
                    }
                }
            }
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
    var mockEntriesSection: some View {
        Section(content: {
            Toggle(isOn: $viewModel.qaService.showMockEntries,
                   label: { Text(verbatim: "Display mocked entries") })

            if viewModel.qaService.showMockEntries {
                Picker(selection: $viewModel.qaService.numberOfMockEntries,
                       content: {
                           ForEach(viewModel.allowedEntriesCount, id: \.self) { count in
                               Text(verbatim: "\(count)")
                           }
                       },
                       label: {
                           Text(verbatim: "Mock entries count")
                       })
            }
        }, header: {
            Text(verbatim: "Mock entries")
        })
    }

    var onboardingSection: some View {
        Section(content: {
            Toggle(isOn: $viewModel.onboarded, label: { Text(verbatim: "Onboarded") })
        }, header: {
            Text(verbatim: "Onboarding")
        })
    }

    var passBannerSection: some View {
        Section(content: {
            Toggle(isOn: $viewModel.displayPassBanner, label: { Text(verbatim: "Display Pass Banner") })
        }, header: {
            Text(verbatim: "Pass Banner")
        })
    }

    var syncSection: some View {
        Section(content: {
            Toggle(isOn: $viewModel.displayBESync, label: { Text(verbatim: "Display BE sync") })
        }, header: {
            Text(verbatim: "Syncs")
        })
    }
}
