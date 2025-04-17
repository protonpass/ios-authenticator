//
// EntriesView.swift
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

import CommonUtilities
import Models

import SimpleToast
import SwiftUI

public struct EntriesView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel = EntriesViewModel()
    @State private var router = Router()
    @State private var showCreationOptions = false
    @State private var draggingEntry: EntryUiModel?
    @State private var isEditing = false

    // periphery:ignore
    private var isPhone: Bool {
        AppConstants.isPhone
    }

    private var searchBarAlignment: VerticalAlignment {
        viewModel.settingsService.searchBarDisplayMode == .bottom ? .bottom : .top
    }

    public init() {}

    public var body: some View {
        NavigationStack {
            mainContainer
                .toastDisplay()
                .safeAreaInset(edge: searchBarAlignment == .bottom ? .bottom : .top) {
                    if viewModel.dataState.data?.isEmpty == false {
                        actionBar
                    }
                }
                .refreshable {
                    viewModel.reloadData()
                }
                .sheetDestinations($router.presentedSheet)
                .environment(router)
                .toolbar { toolbarContent }
                .overlay {
                    overlay
                }
                .adaptiveConfirmationDialog("Create",
                                            isPresented: $showCreationOptions,
                                            actions: {
                                                #if os(iOS)
                                                scanQrCodeButton
                                                #endif
                                                manuallyAddEntryButton
                                            })
                .onChange(of: router.presentedSheet) { _, newValue in
                    viewModel.toggleCodeRefresh(newValue != nil)
                }
                .fullScreenMainBackground()
        }
        .preferredColorScheme(viewModel.settingsService.theme.preferredColorScheme)
        .scrollContentBackground(.hidden)
    }
}

private extension EntriesView {
    @ViewBuilder
    var mainContainer: some View {
        if horizontalSizeClass == .compact {
            list
        } else {
            grid
        }
    }
}

// MARK: - Main display entry

private extension EntriesView {
    var list: some View {
        List {
            ForEach(viewModel.entries) { entry in
                cell(for: entry)
                    .swipeActions {
                        Button {
                            router.presentedSheet = .createEditEntry(entry)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                                .foregroundStyle(.info, .textNorm)
                        }
                        .tint(.clear)

                        Button {
                            viewModel.delete(entry)
                        } label: {
                            Label("Delete", systemImage: "trash.fill")
                                .foregroundStyle(.danger, .textNorm)
                        }
                        .tint(.clear)
                    }
                    .padding(.top, entry == viewModel.entries.first ? 10 : 0)
            }
            .onMove { source, destination in
                viewModel.moveItem(fromOffsets: source, toOffset: destination)
            }
            .padding(.horizontal)
            .listRowInsets(EdgeInsets())
        }
        .listStyle(.plain)
        #if os(iOS)
            .listRowSpacing(12)
        #endif
    }

    var grid: some View {
        ScrollView {
            LazyVGrid(columns: [.init(.flexible()), .init(.flexible())]) {
                ForEach(viewModel.entries) { entry in
                    gridCellLayout(for: entry)
                        .draggable(entry) {
                            cell(for: entry).opacity(0.8)
                                .onAppear {
                                    draggingEntry = entry
                                }
                        }
                        .dropDestination(for: EntryUiModel.self) { _, _ in
                            false
                        } isTargeted: { status in
                            if let draggingEntry,
                               status,
                               draggingEntry != entry,
                               let sourceIndex = viewModel.entries
                               .firstIndex(where: { $0.id == draggingEntry.id }),
                               let destinationIndex = viewModel.entries.firstIndex(where: { $0.id == entry.id }) {
                                withAnimation(.bouncy) {
                                    viewModel.moveItem(fromOffsets: IndexSet(integer: sourceIndex),
                                                       toOffset: destinationIndex > sourceIndex ?
                                                           destinationIndex +
                                                           1 : destinationIndex)
                                }
                            }
                        }
                }
            }
            .animation(.default, value: viewModel.entries)
            .padding()
        }
    }

    func gridCellLayout(for entry: EntryUiModel) -> some View {
        HStack(alignment: .top) {
            cell(for: entry)
            if isEditing {
                VStack(spacing: 10) {
                    Button {
                        router.presentedSheet = .createEditEntry(entry)
                    } label: {
                        Image(systemName: "pencil")
                            .foregroundStyle(.white)
                            .padding(5)
                            .background(.info)
                            .clipShape(.circle)
                    }

                    Button {
                        viewModel.delete(entry)
                    } label: {
                        Image(systemName: "trash.fill")
                            .foregroundStyle(.white)
                            .padding(5)
                            .background(.danger)
                            .clipShape(.circle)
                    }
                }
                .padding(5)
                .background(colorScheme == .light ? .white.opacity(0.7) : .black.opacity(0.7))
                .clipShape(.capsule)
            }
        }
    }

    func cell(for entry: EntryUiModel) -> some View {
        EntryCell(entry: entry.entry,
                  code: entry.code,
                  configuration: viewModel.settingsService.entryCellConfiguration,
                  issuerInfos: entry.issuerInfo,
                  onCopyToken: { viewModel.copyTokenToClipboard(entry) },
                  pauseCountDown: $viewModel.pauseCountDown)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        #if os(macOS)
            .contextMenu {
                Button {
                    router.presentedSheet = .createEditEntry(entry)
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .keyboardShortcut("E", modifiers: [.command, .shift])

                Button {
                    viewModel.delete(entry)
                } label: {
                    Label("Delete", systemImage: "trash.fill")
                }
            }
        #endif
    }
}

// MARK: - Action bar

private extension EntriesView {
    var actionBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            searchBar
            addButton
                .padding(10)
                .frame(width: 44, height: 44, alignment: .center)
                .coloredBackgroundButton(.circle)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 20)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            if searchBarAlignment == .bottom {
                // Top border line
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundStyle(.gradientEnd)
            }
        }
    }

    var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .fontWeight(.medium)
                .foregroundStyle(.textWeak)

            // The actual text field.
            TextField(text: $viewModel.search,
                      label: {
                          Text("Search", bundle: .module)
                      })
                      .adaptiveTextFieldStyle()
                      .foregroundStyle(.textNorm)
                      .submitLabel(.done)
        }

        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colorScheme == .light ? .white.opacity(0.5) : .black.opacity(0.5))
        .clipShape(.capsule)
    }

    @ViewBuilder
    var addButton: some View {
        #if os(iOS)
        if isPhone {
            Button(action: {
                showCreationOptions.toggle()
            }, label: {
                plusIcon
            })
        } else {
            Menu(content: {
                scanQrCodeButton
                manuallyAddEntryButton
            }, label: {
                plusIcon
            })
        }
        #else
        Button(action: {
            router.presentedSheet = .createEditEntry(nil)
        }, label: {
            plusIcon
        })
        .adaptiveButtonStyle()
        #endif
    }

    var plusIcon: some View {
        Image(systemName: "plus")
            .resizable()
            .frame(width: 20, height: 20)
            .foregroundStyle(.white)
    }

    #if os(iOS)
    var scanQrCodeButton: some View {
        Button(action: {
            router.presentedSheet = .qrCodeScanner
        }, label: {
            Label("Scan", systemImage: "qrcode.viewfinder")
        })
    }
    #endif

    var manuallyAddEntryButton: some View {
        Button(action: {
            router.presentedSheet = .createEditEntry(nil)
        }, label: {
            Label("Enter manually", systemImage: "character.cursor.ibeam")
        })
    }
}

// MARK: - Overlay screen

private extension EntriesView {
    @ViewBuilder
    var overlay: some View {
        switch viewModel.dataState {
        case .loading:
            ProgressView()
        case let .loaded(entries):
            if entries.isEmpty {
                ContentUnavailableView {
                    Image(.noCodes)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 210, height: 120)
                        .padding(.bottom, 16)
                } description: {
                    VStack(spacing: 16) {
                        Text("No codes", bundle: .module)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.textNorm)
                            .frame(maxWidth: .infinity, alignment: .top)
                            .opacity(0.9)
                        Text("Protect your accounts with an extra layer of security.", bundle: .module)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.textWeak)
                            .frame(maxWidth: .infinity, alignment: .top)
                            .padding(.horizontal, 48)
                    }
                } actions: {
                    Button {
                        #if os(iOS)
                        showCreationOptions.toggle()
                        #else
                        router.presentedSheet = .createEditEntry(nil)
                        #endif
                    } label: {
                        Text("Create new code", bundle: .module)
                            .foregroundStyle(.white)
                            .fontWeight(.semibold)
                    }
                    .adaptiveButtonStyle()
                    .padding(.horizontal, 30)
                    .padding(.vertical, 14)
                    .coloredBackgroundButton(.capsule)
                }
                .foregroundStyle(.textNorm)
            }
        case let .failed(error):
            RetryableErrorView(tintColor: .danger, error: error) {
                viewModel.reloadData()
            }
        }
    }
}

// MARK: - Toolbar

private extension EntriesView {
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: toolbarItemLeadingPlacement) {
            Text(verbatim: "Authenticator")
                .foregroundStyle(.textNorm)
                .font(.title)
                .fontWeight(.bold)
        }
        #if os(iOS)
        ToolbarItem(placement: .topBarTrailing) {
            trailingContent
        }
        #endif
    }

    // periphery:ignore
    @ViewBuilder
    var trailingContent: some View {
        HStack {
            if AppConstants.isIpad {
                Button {
                    withAnimation {
                        isEditing.toggle()
                    }
                } label: {
                    Text(isEditing ? "Done" : "Edit", bundle: .module)
                        .fontWeight(.medium)
                        .foregroundStyle(isEditing ? .textNorm : .textWeak)
                }
            }
            Button {
                router.presentedSheet = .settings
            } label: {
                Image(.settingsGear)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
            }
            .adaptiveButtonStyle()
        }
    }

    var toolbarItemLeadingPlacement: ToolbarItemPlacement {
        #if os(iOS)
        return .topBarLeading
        #else
        return .automatic
        #endif
    }
}

#Preview {
    EntriesView()
}
