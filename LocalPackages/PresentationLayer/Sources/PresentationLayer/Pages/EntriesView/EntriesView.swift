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
import SimpleToast
import SwiftUI

enum EntryAction: Sendable {
    case copyCurrentCode(EntryUiModel)
    case copyNextCode(EntryUiModel)
    case edit(EntryUiModel)
    case delete(EntryUiModel)
}

public struct EntriesView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = EntriesViewModel()
    @State private var router = Router()
    @State private var draggingEntry: EntryUiModel?
    @State private var hoveringEntry: EntryUiModel?
    @State private var showImportOptions = false
    @State private var searchEnabled = false

    @FocusState private var searchFieldFocus: Bool

    private let alertService = resolve(\ServiceContainer.alertService)

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
                .refreshable { [weak viewModel] in
                    viewModel?.reloadData()
                }
                .safeAreaInset(edge: .top) {
                    if searchBarAlignment == .bottom, viewModel.dataState.data?.isEmpty == false {
                        Color.clear.frame(height: 10)
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    if searchBarAlignment == .bottom, viewModel.dataState.data?.isEmpty == false {
                        actionBar
                    } else if searchBarAlignment == .top, !viewModel.entries.isEmpty {
                        HStack {
                            Spacer()
                            addButton(size: 64)
                                .padding([.trailing, .bottom], DesignConstant.padding * 2)
                                .shadow(color: Color(red: 0.6, green: 0.37, blue: 1).opacity(0.25),
                                        radius: 20,
                                        x: 0,
                                        y: 2)
                        }
                    }
                }
                .if(searchBarAlignment == .top && viewModel.dataState.data?.isEmpty == false) { view in
                    view
                        .searchable(text: $viewModel.query,
                                    isPresented: $searchEnabled,
                                    placement: .navigationBarDrawer(displayMode: .always))
                        .searchFocusable($searchFieldFocus)
                        .asciiCapableKeyboard()
                        .autocorrectionDisabled(true)
                }
                .onAppear {
                    viewModel.reloadData()

                    withAnimation {
                        searchFieldFocus = viewModel.focusSearchOnLaunch
                    }
                }
                .onChange(of: scenePhase) { _, newValue in
                    if newValue == .active {
                        if router.noSheetDisplayed {
                            withAnimation {
                                searchFieldFocus = viewModel.focusSearchOnLaunch
                            }
                        }
                        if viewModel.isAuthenticated {
                            viewModel.fullSync()
                        }
                    }
                }
                .onChange(of: searchFieldFocus) { _, focused in
                    if !focused, ProcessInfo().isiOSAppOnMac {
                        searchEnabled = false
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
                .showSpinner(viewModel.deleteTask != nil)
                .onChange(of: router.presentedFullscreenSheet) { _, newValue in
                    viewModel.toggleCodeRefresh(newValue != nil)
                }
                .onChange(of: router.presentedSheet) { _, newValue in
                    viewModel.toggleCodeRefresh(newValue != nil)
                }
                .onChange(of: router.noSheetDisplayed) { _, newValue in
                    guard newValue, viewModel.focusSearchOnLaunch else {
                        return
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        searchFieldFocus = true
                    }
                }
                .fullScreenMainBackground()
                .importingService($showImportOptions, onMainDisplay: true)
        }
        .preferredColorScheme(viewModel.settingsService.theme.preferredColorScheme)
        .scrollContentBackground(.hidden)
    }
}

private extension EntriesView {
    @ViewBuilder
    var mainContainer: some View {
        Group {
            if horizontalSizeClass == .compact {
                list
            } else {
                GeometryReader { proxy in
                    grid(width: proxy.size.width)
                }
            }
        }
    }
}

// MARK: - Main display entry

private extension EntriesView {
    var list: some View {
        List {
            ForEach(viewModel.entries) { entry in
                cell(for: entry, reducedShadow: false)
                    .contentShape(.dragPreview, RoundedRectangle(cornerRadius: 25))
                    .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 25))
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
            .onMove { source, destination in
                viewModel.moveItem(fromOffsets: source, toOffset: destination)
            }
            .padding(.horizontal)
            .listRowInsets(EdgeInsets())
        }
        .animation(.default, value: viewModel.entries)
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
                ForEach(viewModel.entries) { entry in
                    cell(for: entry)
                        .draggable(entry) {
                            cell(for: entry)
                                .opacity(0.8)
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

    func cell(for entry: EntryUiModel, reducedShadow: Bool = true) -> some View {
        EntryCell(entry: entry,
                  configuration: viewModel.settingsService.entryCellConfiguration,
                  searchTerm: viewModel.query,
                  isHovered: hoveringEntry == entry,
                  reducedShadow: reducedShadow,
                  onAction: handle(_:),
                  pauseCountDown: viewModel.pauseCountDown,
                  animatingEntry: $viewModel.animatingEntry)
            .equatable()
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .accessibility(addTraits: .isButton)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(#localized("issuer %@", bundle: .module, entry.orderedEntry.entry.issuer)
                + ", "
                + #localized("item name: %@", bundle: .module, entry.orderedEntry.entry.name))
            .accessibilityHint(Text("Tap to copy token to clipboard. Swipe left to delete and right to edit.",
                                    bundle: .module))
            .contextMenu {
                EntryOptions(entry: entry, onAction: handle(_:))
            }
            .onHover { over in
                if ProcessInfo().isiOSAppOnMac {
                    if over {
                        hoveringEntry = entry
                    } else if hoveringEntry == entry {
                        hoveringEntry = nil
                    }
                }
            }
    }

    func handle(_ action: EntryAction) {
        switch action {
        case let .copyCurrentCode(entry):
            viewModel.copyTokenToClipboard(entry, current: true)
        case let .copyNextCode(entry):
            viewModel.copyTokenToClipboard(entry, current: false)
        case let .edit(entry):
            router.presentedSheet = .createEditEntry(entry)
        case let .delete(entry):
            viewModel.delete(entry)
        }
    }
}

// MARK: - Action bar

private extension EntriesView {
    var actionBar: some View {
        HStack(alignment: .center, spacing: 10) {
            searchBar
            addButton(size: 42)
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
                      .asciiCapableKeyboard()
                      .autocorrectionDisabled(true)
                      .onSubmit {
                          searchFieldFocus = false
                      }
                      .impactHaptic()

            if AppConstants.isMobile {
                Button(action: {
                    viewModel.cleanSearch()
                }, label: {
                    Image(systemName: "xmark.circle.fill")
                        .fontWeight(.medium)
                        .foregroundStyle(.textWeak)
                        .animation(.default, value: viewModel.query.isEmpty)
                        .opacity(viewModel.query.isEmpty ? 0 : 1)
                })
                .adaptiveButtonStyle()
            }
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
                .frame(width: size, height: size, alignment: .center)
                .coloredBackgroundButton(.circle)
        }
        .adaptiveButtonStyle()
        .impactHaptic()
        .accessibilityLabel("Create new code")
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
                    VStack(spacing: 8) {
                        Text("No codes yet", bundle: .module)
                            .dynamicFont(size: 24, textStyle: .title2, weight: .semibold)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.textNorm)
                            .frame(maxWidth: .infinity, alignment: .top)
                            .opacity(0.9)
                        Text("Protect your accounts with an extra layer of security.", bundle: .module)
                            .dynamicFont(size: 18, textStyle: .title3)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.textWeak)
                            .frame(maxWidth: .infinity, alignment: .top)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 32)

                        VStack(spacing: 16) {
                            let maxWidth: CGFloat = AppConstants.isPhone ? .infinity : 450
                            CapsuleButton(title: "Create new code",
                                          textColor: .white,
                                          style: .borderedFilled,
                                          maxWidth: maxWidth,
                                          action: handleAddNewCode)
                                .impactHaptic()
                            CapsuleButton(title: "Import codes",
                                          textColor: .textNorm,
                                          style: .bordered,
                                          maxWidth: maxWidth,
                                          action: { showImportOptions.toggle() })
                                .impactHaptic()
                        }
                        .frame(minWidth: 262, maxWidth: .infinity)
                    }
                    .padding(.horizontal, 16)
                } actions: {}
                    .refreshable { [weak viewModel] in
                        viewModel?.reloadData()
                    }
            } else if viewModel.entries.isEmpty, !viewModel.query.isEmpty {
                VStack {
                    Spacer()
                    Text("Couldn't find any entries corresponding to your search criteria \"\(viewModel.query)\"",
                         bundle: .module)
                        .dynamicFont(size: 24, textStyle: .title2, weight: .semibold)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.textNorm)
                        .frame(maxWidth: .infinity, alignment: .center)

                    Text("Try searching using different spelling or keywords", bundle: .module)
                        .dynamicFont(size: 18, textStyle: .title3)
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
            Text(verbatim: "Proton Authenticator")
                .foregroundStyle(.textNorm)
                .dynamicFont(size: 28, textStyle: .title1, weight: .bold)
        }
        #if os(iOS)
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                router.presentedSheet = .settings
            } label: {
                Image(.settingsGear)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
            }
            .adaptiveButtonStyle()
            .impactHaptic()
            .accessibilityLabel("Settings")
        }
        #endif
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

private extension View {
    @ViewBuilder
    func asciiCapableKeyboard() -> some View {
        #if os(iOS)
        if AppConstants.isMobile {
            keyboardType(.asciiCapable)
        } else {
            self
        }
        #else
        self
        #endif
    }
}
