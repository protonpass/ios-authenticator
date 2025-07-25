//
//
// EntriesDisplayView.swift
// Proton Authenticator - Created on 24/07/2025.
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
// along with Proton Pass. If not, see https://www.gnu.org/licenses/.
//

import SimpleToast
import SwiftUI

struct EntriesDisplayView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = EntriesDisplayViewModel()

    var body: some View {
        NavigationStack {
            List(viewModel.entries) { entry in
                Button { viewModel.copyToWatchClipboard(entry.token.currentPassword) } label: {
                    TOTPTokenCell(entry: entry)
                }
                .buttonStyle(.plain)
            }
            .animation(.default, value: viewModel.entries)
            .listRowInsets(EdgeInsets())
            .listStyle(.carousel)
            .overlay {
                overlay
            }
            .onChange(of: scenePhase) {
                if scenePhase == .active {
                    Task {
                        await viewModel.askForUpdate()
                    }
                }
            }
            .task {
                viewModel.loadEntries()
            }
            .refreshable {
                await viewModel.askForUpdate()
            }
        }
        .searchable(text: $viewModel.query)
        .toast(toast: $viewModel.toast)
    }
}

private extension EntriesDisplayView {
    @ViewBuilder
    var overlay: some View {
        switch viewModel.dataState {
        case .loading:
            ProgressView()
        case let .loaded(entries):
            if viewModel.entries.isEmpty, viewModel.waitingForData {
                ProgressView()
            } else if entries.isEmpty {
                ContentUnavailableView {
                    Image(systemName: "key.slash.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                        .padding(.bottom, 16)
                } description: {
                    VStack(spacing: 8) {
                        Text("No codes sync with your phone") // ignore:missing_bundle
                            .lineLimit(3)
                            .monospaced()
                            .multilineTextAlignment(.center)
                            .opacity(0.9)

                        VStack(spacing: 16) {
                            Button { viewModel.loadEntries() } label: {
                                Text("Sync now") // ignore:missing_bundle
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 16)
                } actions: {}
            } else if viewModel.entries.isEmpty, !viewModel.query.isEmpty {
                VStack {
                    Spacer()
                    Text("Couldn't find any entries corresponding to your search criteria \"\(viewModel.query)\"") // ignore:missing_bundle
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.textNorm)
                        .frame(maxWidth: .infinity, alignment: .center)

                    Text("Try searching using different spelling or keywords") // ignore:missing_bundle
                        .foregroundStyle(.textWeak)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)

                    Spacer()
                }
                .frame(maxHeight: .infinity)
                .padding(.horizontal)
            }
        case let .failed(error):
            RetryErrorView(tintColor: .danger, error: error) {
                Task {
                    await viewModel.askForUpdate()
                }
            }
        }
    }
}
