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
import FactoryKit
import Macro
import Models
import SwiftUI

enum EntryAction: Equatable, Hashable {
    case copyCurrentCode(EntryUiModel)
    case copyNextCode(EntryUiModel)
    case edit(EntryUiModel)
    case delete(EntryUiModel)

    var entryUiModel: EntryUiModel {
        switch self {
        case let .copyCurrentCode(entry),
             let .copyNextCode(entry),
             let .delete(entry),
             let .edit(entry):
            entry
        }
    }

    var entry: Entry {
        entryUiModel.orderedEntry.entry
    }

    var isCurrentCodeCopyAction: Bool {
        guard case .copyCurrentCode = self else {
            return false
        }
        return true
    }
}

public struct EntriesView: View {
    @Environment(\.horizontalSizeClass)
    private var horizontalSizeClass
    @Environment(\.scenePhase)
    private var scenePhase
    @InjectedObservable(\ViewModelContainer.entriesViewModel)
    private var viewModel
    @State private var router = Router()
    @State private var draggingEntry: EntryUiModel?
    @State private var hoveringEntry: EntryUiModel?
    @State private var destinationIndex: Int?
    @State private var showImportOptions = false
    @State private var searchEnabled = false
    // Debounced mirror of `!viewModel.noEntries`. When the first entry is added on iOS 26,
    // attaching `.searchable` in the same frame as the new `DefaultToolbarItem(.search, .bottomBar)`
    // leaves the bottom search capsule rendered without its placeholder/icon. Delaying the
    // `.searchable` attachment by one run-loop tick lets the toolbar slot mount first, so the
    // searchable binding wires up cleanly.
    @State private var attachSearchable = false
    @FocusState private var searchFieldFocus: Bool

    private let alertService = resolve(\ServiceContainer.alertService)

    private var searchBarAlignment: VerticalAlignment {
        viewModel.settingsService.searchBarDisplayMode == .bottom ? .bottom : .top
    }

    public init() {}

    public var body: some View {
        NavigationStack {
            mainContainer // swiftlint:disable:this accessibility_trait_for_button
                .scrollDismissesKeyboard(.immediately)
                .onTapGesture {
                    searchFieldFocus = false
                }
                .refreshable { [weak viewModel] in
                    viewModel?.reloadData()
                }
                .safeAreaInset(edge: .top) {
                    if #unavailable(iOS 26, macOS 26) {
                        if searchBarAlignment == .bottom, !viewModel.noEntries {
                            Color.clear.frame(height: 10)
                        }
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    if searchBarAlignment == .bottom,
                       !viewModel.noEntries,
                       #unavailable(iOS 26, macOS 26) {
                        EntriesActionBar(query: $viewModel.query,
                                         cleanSearch: viewModel.cleanSearch,
                                         searchFieldFocus: $searchFieldFocus,
                                         onAddNewCode: handleAddNewCode)
                    } else if searchBarAlignment == .top, !viewModel.entries.isEmpty {
                        HStack {
                            Spacer()
                            AddEntryButton(size: 44, action: handleAddNewCode)
                                .padding(.trailing, DesignConstant.padding * 2)
                                .padding(.bottom, DesignConstant.padding)
                                .shadow(color: Color(red: 0.6, green: 0.37, blue: 1).opacity(0.25),
                                        radius: 20,
                                        x: 0,
                                        y: 2)
                        }
                    }
                }
                .if(nativeSearchable && attachSearchable) { view in
                    view
                        .searchable(text: $viewModel.query,
                                    isPresented: $searchEnabled,
                                    placement: searchFieldPlacement)
                        .searchFocusable($searchFieldFocus)
                        .asciiCapableKeyboard()
                        .autocorrectionDisabled(true)
                }
                .onAppear {
                    viewModel.reloadData()

                    withAnimation {
                        searchFieldFocus = viewModel.focusSearchOnLaunch
                    }

                    attachSearchable = !viewModel.noEntries
                }
                .onChange(of: viewModel.noEntries) { _, noEntries in
                    if noEntries {
                        attachSearchable = false
                    } else {
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(50))
                            attachSearchable = true
                        }
                    }
                }
                .onChange(of: scenePhase) { _, newValue in
                    if newValue == .active {
                        viewModel.checkWatchConnectivity()
                        if router.noSheetDisplayed {
                            withAnimation {
                                searchFieldFocus = viewModel.focusSearchOnLaunch
                            }
                        }
                        viewModel.reloadData()
                    }
                }
                .onChange(of: searchFieldFocus) { _, focused in
                    if !focused, ProcessInfo.processInfo.isiOSAppOnMac {
                        searchEnabled = false
                    }
                }
                .onChange(of: viewModel.dataState) {
                    viewModel.refreshSearchResults()
                }
                .onChange(of: viewModel.sortOption) {
                    viewModel.refreshEntries()
                }
                .sheetDestinations($router.presentedSheet)
            #if os(iOS)
                .fullScreenDestination($router.presentedFullscreenSheet)
            #endif
                .environment(router)
                .toolbar {
                    EntriesToolbarContent(sortOption: viewModel.sortOption,
                                          setSortOption: viewModel.settingsService.setSortOption,
                                          presentedSheet: $router.presentedSheet,
                                          searchBarAlignment: searchBarAlignment,
                                          noEntries: viewModel.noEntries,
                                          handleAddNewCode: handleAddNewCode)
                }
                .overlay {
                    EntriesEmptyStateView(dataState: viewModel.dataState,
                                          query: viewModel.query,
                                          entriesEmpty: viewModel.entries.isEmpty,
                                          handleAddNewCode: handleAddNewCode,
                                          showImportOptions: $showImportOptions,
                                          reloadData: viewModel.reloadData)
                }
                .showSpinner(viewModel.deleteTask != nil)
                .onChange(of: router.noSheetDisplayed) { _, isNoSheet in
                    viewModel.toggleCodeRefresh(!isNoSheet)
                    if isNoSheet, viewModel.focusSearchOnLaunch {
                        Task {
                            try? await Task.sleep(for: .milliseconds(200))
                            searchFieldFocus = true
                        }
                    }
                }
                .blur(radius: router.noSheetDisplayed ? 0 : 8)
                .animation(.default, value: router.noSheetDisplayed)
                .fullScreenMainBackground()
                .navigationBarTitleDisplayMode(.inline)
                .sheet(item: $viewModel.inAppService.currentMessage,
                       content: { message in
                           InAppMessageView(message: message)
                               .onDisappear {
                                   viewModel.inAppService.dismissPermanently(message)
                               }
                       })
        }
        // Force re-rendering the whole view to take into account search bar position mode
        // because `searchable` modifier seems to be cached by SwiftUI so it doesn't reflect changes
        .id(viewModel.settingsService.searchBarDisplayMode)
        .preferredColorScheme(viewModel.settingsService.theme.preferredColorScheme)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Helpers

private extension EntriesView {
    @ViewBuilder
    var mainContainer: some View {
        if horizontalSizeClass == .compact {
            list
        } else {
            GeometryReader { proxy in
                grid(width: proxy.size.width)
            }
        }
    }

    var nativeSearchable: Bool {
        switch searchBarAlignment {
        case .top:
            true

        case .bottom:
            if #available(iOS 26, macOS 26, *) {
                true
            } else {
                false
            }

        default:
            false
        }
    }

    var searchFieldPlacement: SearchFieldPlacement {
        if AppConstants.adjustableSearchBarPosition {
            searchBarAlignment == .top ? .navigationBarDrawer(displayMode: .always) : .toolbar
        } else {
            .toolbar
        }
    }
}

// MARK: - Main display entry

private extension EntriesView {
    var list: some View {
        List {
            ForEach(viewModel.entries) { entry in
                cell(for: entry, reducedShadow: false)
                    .contentShape(.dragPreview, RoundedRectangle(cornerRadius: 18))
                    .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 18))
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
                        .disabled(viewModel.deleteTask != nil)
                    }
            }
            .onMove(perform: viewModel.sortOption.isManual ? { source, destination in
                viewModel.moveItem(fromOffsets: source, toOffset: destination)
            } : nil)
            .padding(.horizontal)
            .listRowInsets(EdgeInsets())
        }
        .listStyle(.plain)
        #if os(iOS)
            .listRowSpacing(12)
        #endif
    }

    @ViewBuilder
    func grid(width: CGFloat) -> some View {
        let entryMinWidth: CGFloat = 650
        let columnCount = min(Int(ceil(width / entryMinWidth)), viewModel.entries.count)

        ScrollView {
            LazyVGrid(columns: [GridItem](repeating: GridItem(.flexible()), count: columnCount)) {
                ForEach(viewModel.reorderingEntries ?? viewModel.entries) { entry in
                    cell(for: entry)
                        .if(viewModel.sortOption.isManual) { view in
                            view
                                .draggable(entry.orderedEntry.id) {
                                    cell(for: entry)
                                        .opacity(0.8)
                                        .onAppear {
                                            viewModel.reorderingEntries = viewModel.entries
                                            draggingEntry = entry
                                        }
                                }
                        }
                        .dropDestination(for: String.self) { _, _ in
                            guard
                                let draggingEntry,
                                let sourceIndex = viewModel.entries
                                .firstIndex(where: { $0.id == draggingEntry.id }),
                                let destinationIndex
                            else {
                                viewModel.reorderingEntries = nil
                                return false
                            }

                            withAnimation(.bouncy) {
                                viewModel.moveItem(fromOffsets: IndexSet(integer: sourceIndex),
                                                   toOffset: destinationIndex > sourceIndex ? destinationIndex +
                                                       1 :
                                                       destinationIndex)
                            }

                            return true
                        } isTargeted: { status in
                            guard
                                let draggingEntry,
                                status,
                                draggingEntry != entry,
                                let sourceIndex = viewModel.reorderingEntries?
                                .firstIndex(where: { $0.id == draggingEntry.id })
                            else { return }

                            destinationIndex = viewModel.reorderingEntries?
                                .firstIndex(where: { $0.id == entry.id })
                            guard let destinationIndex else {
                                return
                            }

                            withAnimation(.bouncy) {
                                viewModel.reorderingEntries?.move(fromOffsets: IndexSet(integer: sourceIndex),
                                                                  toOffset: destinationIndex > sourceIndex ?
                                                                      destinationIndex + 1 :
                                                                      destinationIndex)
                            }
                        }
                }
            }
            .padding()
        }
    }

    // swiftlint:disable line_length
    func cell(for entry: EntryUiModel, reducedShadow: Bool = true) -> some View {
        EntryCell(entry: entry,
                  configuration: viewModel.settingsService.entryCellConfiguration,
                  searchTerm: viewModel.query,
                  isHovered: hoveringEntry == entry,
                  reducedShadow: reducedShadow,
                  onAction: handle(_:),
                  animatingEntryAction: $viewModel.animatingEntry)
            .equatable()
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .accessibility(addTraits: .isButton)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: "\(entry.orderedEntry.entry.issuer), \(entry.orderedEntry.entry.name) \(#localized("code: %@", bundle: .module, entry.code.current))"))
            .accessibilityHint(Text("Tap to copy token to clipboard. Swipe left to delete and right to edit.",
                                    bundle: .module))
            .contextMenu {
                EntryOptions(entry: entry, onAction: handle(_:))
            }
            .onHover { over in
                if ProcessInfo.processInfo.isiOSAppOnMac {
                    if over {
                        hoveringEntry = entry
                    } else if hoveringEntry == entry {
                        hoveringEntry = nil
                    }
                }
            }
    }

    // swiftlint:enable line_length
}

// MARK: - Actions

private extension EntriesView {
    func handle(_ action: EntryAction) {
        // Reset `reorderingEntries` to exit dragging mode
        // otherwise the list is not updated after deleting an entry
        viewModel.reorderingEntries = nil
        switch action {
        case .copyCurrentCode:
            viewModel.copyTokenToClipboard(entryAction: action)

        case .copyNextCode:
            viewModel.copyTokenToClipboard(entryAction: action)

        case let .edit(entry):
            router.presentedSheet = .createEditEntry(entry)

        case let .delete(entry):
            viewModel.delete(entry)
        }
    }

    func handleAddNewCode() {
        #if os(macOS)
        router.presentedSheet = .createEditEntry(nil)
        #else
        if AppConstants.isMobile {
            showScannerIfCameraAvailable()
        } else {
            router.presentedSheet = .createEditEntry(nil)
        }
        #endif
    }

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
