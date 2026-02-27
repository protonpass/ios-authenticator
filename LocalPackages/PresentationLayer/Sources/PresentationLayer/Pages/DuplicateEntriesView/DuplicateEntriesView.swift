//
// DuplicateEntriesView.swift
// Proton Authenticator - Created on 25/02/2026.
// Copyright (c) 2026 Proton Technologies AG
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

import CommonUtilities
import DataLayer
import Macro
import SwiftUI

struct DuplicateEntriesView: View {
    @State private var viewModel = DuplicateEntriesViewModel()

    var body: some View {
        content
            .task { await viewModel.loadGroups() }
            .navigationTitle(Text("Duplicate entries", bundle: .module))
            .showSpinner(viewModel.loading)
            .errorMessageAlert($viewModel.errorMessage)
            .scrollContentBackground(.hidden)
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .fullScreenMainBackground()
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.groups.isEmpty, !viewModel.loading {
            emptyState
        } else {
            groupList
        }
    }

    // swiftlint:disable:next todo
    // TODO: content state implementation
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundStyle(.accent)
            Text("No duplicate entries", bundle: .module)
                .dynamicFont(size: 17, textStyle: .body)
                .foregroundStyle(.textNorm)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var groupList: some View {
        List {
            ForEach(viewModel.groups) { group in
                Section {
                    ForEach(group.entries) { entry in
                        entryRow(entry)
                    }
                } header: {
                    Text(verbatim: group.issuer.isEmpty ? group.displayName : group.issuer)
                }
            }
        }
    }

    private func entryRow(_ entry: DuplicateEntryInfo) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: viewModel.formattedDate(for: entry.modifiedTime))
                    .dynamicFont(size: 15, textStyle: .body)
                    .foregroundStyle(.textNorm)
                if entry.isCurrentlyActive {
                    Text("Currently used", bundle: .module)
                        .dynamicFont(size: 13, textStyle: .caption1)
                        .foregroundStyle(.accent)
                }
            }
            Spacer()
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                viewModel.delete(entryId: entry.entryId, modifiedTime: entry.modifiedTime)
            } label: {
                Label { Text("Delete", bundle: .module) } icon: { Image(systemName: "trash") }
            }
        }
    }
}

#Preview {
    DuplicateEntriesView()
}
