//
//
// LogsView.swift
// Proton Authenticator - Created on 16/04/2025.
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
import Models
import SwiftUI

struct LogsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = LogsViewModel()

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.logs) { log in
                    Text(verbatim: log.description)
                        .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .toolbar {
                ToolbarItem(placement: toolbarItemPlacement) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Close", bundle: .module)
                            .foregroundStyle(.accent)
                    }
                    .adaptiveButtonStyle()
                }

                ToolbarItem(placement: toolbarTrailingItemPlacement) {
                    Button {
                        viewModel.exportLogs()
                    } label: {
                        Text("Share", bundle: .module)
                            .foregroundStyle(.purpleInteraction)
                    }
                    .adaptiveButtonStyle()
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle(Text("Logs", bundle: .module))
            #if os(iOS)
                .listSectionSpacing(DesignConstant.padding * 2)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toastDisplay()
                .mainBackground()
                .sheetAlertService()
                .fileExporter(isPresented: $viewModel.exportedDocument.mappedToBool(),
                              document: viewModel.exportedDocument,
                              contentType: .text,
                              defaultFilename: viewModel.generateExportFileName(),
                              onCompletion: viewModel.handleExportResult)
        }
        #if os(macOS)
        .frame(minWidth: 800, minHeight: 600)
        #endif
    }

    private var toolbarItemPlacement: ToolbarItemPlacement {
        #if os(iOS)
        return .topBarLeading
        #else
        return .automatic
        #endif
    }

    private var toolbarTrailingItemPlacement: ToolbarItemPlacement {
        #if os(iOS)
        return .topBarTrailing
        #else
        return .automatic
        #endif
    }
}

#Preview {
    LogsView()
}
