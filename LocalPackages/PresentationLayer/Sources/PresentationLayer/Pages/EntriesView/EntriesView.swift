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

import AVFoundation
import CommonUtilities
import DataLayer
import Factory
import Models
import SimpleToast
import SwiftUI

public struct EntriesView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = EntriesViewModel()
    @State private var router = Router()
    @State private var draggingEntry: EntryUiModel?
    @State private var isEditing = false

    @FocusState private var searchFieldFocus: Bool

    // periphery:ignore
    private let alertService = resolve(\ServiceContainer.alertService)

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
                .scrollDismissesKeyboard(.immediately)
                .onTapGesture {
                    searchFieldFocus = false
                }
                .toastDisplay()
                .safeAreaInset(edge: .top) {
                    if searchBarAlignment == .bottom, viewModel.dataState.data?.isEmpty == false {
                        Color.clear.frame(height: 10)
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    if searchBarAlignment == .bottom, viewModel.dataState.data?.isEmpty == false {
                        actionBar
                    }
                }
                .if(searchBarAlignment == .top && viewModel.dataState.data?.isEmpty == false) { view in
                    view
                        .searchable(text: $viewModel.query)
                }
                .refreshable { [weak viewModel] in
                    viewModel?.reloadData()
                }
                .onAppear {
                    withAnimation {
                        searchFieldFocus = viewModel.focusSearchOnLaunch
                    }
                }
                .onChange(of: scenePhase) { _, newValue in
                    if newValue == .active {
                        withAnimation {
                            searchFieldFocus = viewModel.focusSearchOnLaunch
                        }
                        if viewModel.isAuthenticated {
                            viewModel.fullSync()
                        }
                    }
                }
                .sheetDestinations($router.presentedSheet)
            #if os(iOS)
                .fullScreenDestination($router.presentedFullscreenSheet)
            #endif
                .environment(router)
                .toolbar { toolbarContent }
                .overlay {
                    overlay
                }
                .onChange(of: router.presentedFullscreenSheet) { _, newValue in
                    viewModel.toggleCodeRefresh(newValue != nil)
                }
                .onChange(of: router.presentedSheet) { _, newValue in
                    viewModel.toggleCodeRefresh(newValue != nil)
                }
                .fullScreenMainBackground()
                .animation(.default, value: viewModel.entries)
        }
        .preferredColorScheme(viewModel.settingsService.theme.preferredColorScheme)
        .scrollContentBackground(.hidden)
    }
}

private extension EntriesView {
    @ViewBuilder
    var mainContainer: some View {
        ZStack(alignment: .bottomTrailing) {
            if horizontalSizeClass == .compact {
                list
            } else {
                grid
            }

            if searchBarAlignment == .top {
                addButton(size: 52)
                    .padding([.trailing, .bottom], DesignConstant.padding * 2)
            }
        }
    }
}

// MARK: - Main display entry

private extension EntriesView {
    var list: some View {
        List {
            ForEach(viewModel.entries) { entry in
                cell(for: entry)
                    .swipeActions(edge: .leading) {
                        Button {
                            router.presentedSheet = .createEditEntry(entry)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(Color.editSwipe)
                    }
                    .swipeActions(edge: .trailing) {
                        Button {
                            viewModel.delete(entry)
                        } label: {
                            Label("Delete", systemImage: "trash.fill")
                        }
                        .tint(Color.deleteSwipe)
                    }
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
                  searchTerm: viewModel.query,
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
        HStack(alignment: .bottom, spacing: 10) {
            searchBar
            addButton(size: 44)
                .padding(10)
        }
        .padding(.horizontal, 22)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(.bar)
        .background(LinearGradient(stops:
            [
                Gradient.Stop(color: .black.opacity(0.5), location: 0.00),
                Gradient.Stop(color: .black.opacity(0), location: 1.00)
            ],
            startPoint: UnitPoint(x: 0.5, y: 1),
            endPoint: UnitPoint(x: 0.5, y: 0)))
        .overlay(alignment: .top) {
            // Top border line
            Rectangle()
                .frame(height: 0.5)
                .foregroundStyle(.actionBarBorder)
        }
    }

    var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .fontWeight(.medium)
                .foregroundStyle(.textWeak)

            // The actual text field.
            TextField(text: $viewModel.query,
                      label: {
                          Text("Search", bundle: .module)
                              .foregroundStyle(.textWeak)
                      })
                      .adaptiveTextFieldStyle()
                      .foregroundStyle(.textNorm)
                      .submitLabel(.done)
                      .focused($searchFieldFocus)
                      .onSubmit {
                          searchFieldFocus = false
                      }
                      .impactHaptic()

            Button(action: {
                viewModel.query = ""
            }, label: {
                Image(systemName: "xmark.circle.fill")
                    .fontWeight(.medium)
                    .foregroundStyle(.textWeak)
                    .animation(.default, value: viewModel.query.isEmpty)
                    .opacity(viewModel.query.isEmpty ? 0 : 1)
            })
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Capsule()
            .fill(.shadow(.inner(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)))
            .shadow(color: .white.opacity(0.2),
                    radius: 1,
                    x: 0,
                    y: 0.5)
            .foregroundStyle(colorScheme == .light ? Color(red: 0.9, green: 0.9, blue: 0.89)
                .opacity(0.7) : Color(red: 0.06,
                                      green: 0.06,
                                      blue: 0.06).opacity(0.8)))
    }

    func addButton(size: CGFloat) -> some View {
        Button(action: handleAddNewCode) {
            plusIcon
        }
        .adaptiveButtonStyle()
        .frame(width: size, height: size, alignment: .center)
        .coloredBackgroundButton(.circle)
        .impactHaptic()
    }

    func handleAddNewCode() {
        #if os(iOS)
        showScannerIfCameraAvailable()
        #else
        router.presentedSheet = .createEditEntry(nil)
        #endif
    }

    var plusIcon: some View {
        Image(systemName: "plus")
            .resizable()
            .frame(width: 20, height: 20)
            .foregroundStyle(.white)
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
                            .font(.title3)
                            .monospaced()
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.textNorm)
                            .frame(maxWidth: .infinity, alignment: .top)
                            .opacity(0.9)
                        Text("Protect your accounts with an extra layer of security.", bundle: .module)
                            .font(.headline)
                            .monospaced()
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.textWeak)
                            .frame(maxWidth: .infinity, alignment: .top)
                            .padding(.horizontal, 16)
                    }
                } actions: {
                    Button(action: handleAddNewCode) {
                        Text("Create new code", bundle: .module)
                            .foregroundStyle(.white)
                            .fontWeight(.semibold)
                    }
                    .adaptiveButtonStyle()
                    .padding(.horizontal, 30)
                    .padding(.vertical, 14)
                    .coloredBackgroundButton(.capsule)
                    .impactHaptic()
                }
                .foregroundStyle(.textNorm)
            } else if viewModel.entries.isEmpty, !viewModel.query.isEmpty {
                VStack {
                    Spacer()
                    Text("Couldn't find any entries corresponding to your search criteria \"\(viewModel.query)\"",
                         bundle: .module)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.textNorm)
                        .frame(maxWidth: .infinity, alignment: .center)

                    Text("Try searching using different spelling or keywords", bundle: .module)
                        .foregroundStyle(.textWeak)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)

                    Spacer()
                }
                .frame(maxHeight: .infinity)
                .padding(.horizontal)
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
                    isEditing.toggle()
                } label: {
                    Text(isEditing ? "Done" : "Edit", bundle: .module)
                        .fontWeight(.medium)
                        .foregroundStyle(isEditing ? .textNorm : .textWeak)
                        .disableAnimations()
                }
                .opacity(viewModel.entries.isEmpty ? 0 : 1)
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
            .impactHaptic()
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

private extension EntriesView {
    #if os(iOS)
    func showScannerIfCameraAvailable() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized, .notDetermined:
            router.presentedFullscreenSheet = .qrCodeScanner
        case .denied, .restricted:
            let config = AlertConfiguration.noCameraAccess {
                router.presentedSheet = .createEditEntry(nil)
            }
            alertService.showAlert(.main(config))
        @unknown default:
            router.presentedFullscreenSheet = .qrCodeScanner
        }
    }
    #endif
}

#Preview {
    EntriesView()
}
