//
// EntriesViewModel.swift
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

import Combine
import CommonUtilities
import DataLayer
import FactoryKit
import Foundation
import Macro
import Models

@Observable
final class EntriesViewModel {
    var animatingEntry: EntryAction?

    var reorderingEntries: [EntryUiModel]?

    private(set) var entries: [EntryUiModel] = []

    var dataState: DataState<[EntryUiModel]> {
        entryDataService.dataState
    }

    var noEntries: Bool {
        dataState.data?.isEmpty == true
    }

    var focusSearchOnLaunch: Bool {
        settingsService.focusSearchOnLaunch
    }

    var isAuthenticated: Bool {
        userSessionManager.isAuthenticatedWithUserData.value
    }

    var sortOption: SortOption {
        settingsService.sortOption
    }

    var query = "" {
        didSet {
            searchTextStream.send(query)
        }
    }

    @ObservationIgnored
    private var badgeTask: Task<Void, Never>?

    @ObservationIgnored
    private var searchResults: [EntryUiModel]?

    @ObservationIgnored
    private let searchTextStream: CurrentValueSubject<String, Never> = .init("")

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.entryDataService)
    private(set) var entryDataService

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.totpCountdownManager)
    private(set) var totpCountdownManager

    @ObservationIgnored
    @LazyInjected(\UseCaseContainer.copyTextToClipboard)
    private var copyTextToClipboard

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.alertService)
    private var alertService

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.userSessionManager)
    private(set) var userSessionManager

    @ObservationIgnored
    @LazyInjected(\UseCaseContainer.userDataRefresh)
    private var userDataRefresh

    // periphery:ignore
    @ObservationIgnored
    @Injected(\ServiceContainer.iosToWatchCommunicationManager)
    private var iosToWatchCommunicationManager

    @ObservationIgnored
    @LazyInjected(\ToolsContainer.logManager)
    private(set) var logger

    #if os(iOS)
    @ObservationIgnored
    @LazyInjected(\ToolsContainer.hapticsManager)
    private var hapticsManager
    #endif

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.settingsService)
    private(set) var settingsService

    @ObservationIgnored
    @LazyInjected(\UseCaseContainer.requestForReview)
    private var requestForReview

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.inAppMessagingService)
    var inAppService

    @ObservationIgnored
    @LazyInjected(\UseCaseContainer.authenticateBiometrically)
    private var authenticateBiometrically

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.localDataManager)
    private var localDataManager

    @ObservationIgnored
    @LazyInjected(\ToolsContainer.updatingSettings)
    private var updatingSettings

    @ObservationIgnored
    private var disableICloudTask: Task<Void, Never>?

    @ObservationIgnored
    private var cancellables = Set<AnyCancellable>()

    @ObservationIgnored
    private var loadLocalTask: Task<Void, Never>?
    @ObservationIgnored
    private var fullSyncTask: Task<Void, Never>?
    @ObservationIgnored
    private var searchTask: Task<Void, Never>?

    private(set) var deleteTask: Task<Void, Never>?

    init() {
        searchTextStream
            .dropFirst()
            .removeDuplicates()
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] query in
                guard let self else { return }
                executeSearch(query: query)
            }
            .store(in: &cancellables)

        userSessionManager.isAuthenticatedWithUserData
            .receive(on: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] status in
                guard let self, status else { return }
                fullSync(refreshUserData: false)
            }
            .store(in: &cancellables)

        userSessionManager.sessionWasInvalidated
            .receive(on: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] status in
                guard let self, status else { return }
                alertService.showAlert(.main(.init(title: "Sync between your devices is paused",
                                                   titleBundle: .module,
                                                   // swiftlint:disable:next line_length
                                                   message: .localized("Your session is expired or revoked, please log in to your Proton account again.",
                                                                       .module),
                                                   actions: [.ok])))
            }
            .store(in: &cancellables)
    }

    func moveItem(fromOffsets source: IndexSet, toOffset destination: Int) {
        // Get the actual index values after removing
        guard let offset = source.first else {
            return
        }
        var targetIndex = destination

        // Adjust the destination if moving downward in the list
        if offset < destination {
            targetIndex -= 1
        }
        guard offset != targetIndex else {
            return
        }
        Task { [weak self] in
            guard let self else { return }
            defer { reorderingEntries = nil }
            do {
                try await entryDataService.reorderItem(from: offset, to: targetIndex)
                await requestForReview()
            } catch {
                handle(error)
            }
        }
    }

    func loadEntries() {
        guard loadLocalTask == nil else {
            return
        }
        loadLocalTask = Task { [weak self] in
            guard let self else { return }
            defer {
                loadLocalTask = nil
            }
            do {
                if Task.isCancelled {
                    return
                }
                try await entryDataService.loadEntries()
                if Task.isCancelled {
                    return
                }
            } catch {
                handle(error)
            }
        }
    }

    func checkWatchConnectivity() {
        iosToWatchCommunicationManager.checkIfActive()
    }

    func cleanSearch() {
        query = ""
    }
}

extension EntriesViewModel {
    func reloadData() {
        if isAuthenticated {
            fullSync()
        } else {
            loadEntries()
        }
    }

    func copyTokenToClipboard(entryAction: EntryAction) {
        guard entryAction != animatingEntry else {
            return
        }
        animatingEntry = entryAction
        let code = entryAction.entryUiModel.code
        let codeValue = entryAction.isCurrentCodeCopyAction ? code.current : code.next
        assert(!codeValue.isEmpty, "Code should not be empty")
        copyTextToClipboard(codeValue)
        #if os(iOS)
        hapticsManager(.defaultImpact)
        #endif
        badgeTask?.cancel()
        badgeTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            animatingEntry = nil
            badgeTask = nil
        }
    }

    func toggleCodeRefresh(_ shouldPause: Bool) {
        if shouldPause {
            totpCountdownManager.stopTimer()
            entryDataService.stopTotpGenerator()
        } else {
            totpCountdownManager.startTimer()
            entryDataService.startTotpGenerator()
        }
    }

    func delete(_ entry: EntryUiModel) {
        let action = ActionConfig(title: "Yes",
                                  titleBundle: .module,
                                  role: .destructive,
                                  action: { [weak self] in
                                      guard let self else {
                                          return
                                      }
                                      confirmDelete(entry)
                                  })
        alertService.showAlert(.main(.init(title: "Delete entry",
                                           titleBundle: .module,
                                           // swiftlint:disable:next line_length
                                           message: .localized("Are you sure you want to delete this entry? This action is irreversible.",
                                                               .module),
                                           actions: [action])))
    }

    func showICloudDisablePromptIfNeeded() {
        guard settingsService.iCloudSync,
              !settingsService.iCloudDisablePromptDismissed,
              settingsService.onboarded else {
            return
        }

        settingsService.setICloudDisablePromptDismissed(true)

        let disableAction = ActionConfig(title: "Disable iCloud sync",
                                         titleBundle: .module,
                                         action: { [weak self] in
                                             guard let self else { return }
                                             disableICloudSyncFromPrompt()
                                         })

        alertService.showAlert(.main(.init(title: "Switch off iCloud sync",
                                           titleBundle: .module,
                                           // swiftlint:disable:next line_length
                                           message: .localized("Due to reliability issues with Apple's iCloud, we recommend using Proton sync and/or backup system instead.",
                                                               .module),
                                           actions: [disableAction, .ok])))
    }

    func disableICloudSyncFromPrompt() {
        guard disableICloudTask == nil else { return }
        disableICloudTask = Task { [weak self] in
            guard let self else { return }
            defer {
                disableICloudTask = nil
                updatingSettings.send(false)
            }
            updatingSettings.send(true)
            let reason = #localized("Please authenticate", bundle: .module)
            do {
                if try await authenticateBiometrically(policy: AppConstants.laEnablingPolicy,
                                                       reason: reason) {
                    settingsService.toggleICloudSync(false)
                    await localDataManager.refreshLocalStorage()
                }
            } catch {
                handle(error)
            }
        }
    }

    func refreshSearchResults() {
        executeSearch(query: query)
    }

    func refreshEntries() {
        updateEntries()
    }
}

private extension EntriesViewModel {
    func fullSync(refreshUserData: Bool = true) {
        guard fullSyncTask == nil else {
            return
        }
        fullSyncTask = Task { [weak self] in
            guard let self else { return }
            defer {
                fullSyncTask = nil
            }
            do {
                if let loadTask = loadLocalTask {
                    await loadTask.value
                }
                if Task.isCancelled {
                    return
                }
                if refreshUserData {
                    do {
                        try await userDataRefresh()
                    } catch {
                        logger.log(.error,
                                   category: .network,
                                   "User data refresh failed: \(error.localizedDescription)")
                    }
                }
                if Task.isCancelled {
                    return
                }
                try await entryDataService.fullRefresh()
                if Task.isCancelled {
                    return
                }
            } catch {
                handle(error)
            }
        }
    }

    func handle(_ error: any Error, function: String = #function, line: Int = #line) {
        guard !alertService.isShowingAlert else {
            return
        }
        logger.log(.error, category: .ui, error.localizedDescription, function: function, line: line)
        alertService.showError(error, mainDisplay: true, action: nil)
    }

    func executeSearch(query: String) {
        searchTask?.cancel()
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty {
            searchResults = nil
            updateEntries()
            return
        }

        searchTask = Task { [weak self] in
            guard let self, let data = entryDataService.dataState.data else {
                return
            }
            if Task.isCancelled {
                return
            }
            searchResults = await filterData(query: query, data: data)
            updateEntries()
        }
    }

    @concurrent
    func filterData(query: String, data: [EntryUiModel]) async -> [EntryUiModel] {
        data.filter {
            $0.orderedEntry.entry.name.lowercased().contains(query) ||
                $0.orderedEntry.entry.issuer.lowercased().contains(query)
        }
    }

    func updateEntries() {
        if let results = searchResults {
            entries = results.sorted(by: settingsService.sortOption)
        } else if let data = entryDataService.dataState.data {
            entries = data.sorted(by: settingsService.sortOption)
        } else {
            entries = []
        }
    }

    func confirmDelete(_ entry: EntryUiModel) {
        guard deleteTask == nil else { return }
        deleteTask = Task { [weak self] in
            guard let self else { return }
            defer { deleteTask = nil }
            do {
                try await entryDataService.delete(entry)
            } catch {
                handle(error)
            }
        }
    }
}

private extension [EntryUiModel] {
    func sorted(by option: SortOption) -> Self {
        switch option {
        case .manual:
            self

        case .issuerAsc:
            sorted(by: {
                $0.orderedEntry.entry.issuer.lowercased() < $1.orderedEntry.entry.issuer.lowercased()
            })

        case .issuerDesc:
            sorted(by: {
                $0.orderedEntry.entry.issuer.lowercased() > $1.orderedEntry.entry.issuer.lowercased()
            })

        case .creationDateAsc:
            sorted(by: { $0.orderedEntry.creationDate < $1.orderedEntry.creationDate })

        case .creationDateDesc:
            sorted(by: { $0.orderedEntry.creationDate > $1.orderedEntry.creationDate })

        case .modificationDateAsc:
            sorted(by: { $0.orderedEntry.modifiedTime < $1.orderedEntry.modifiedTime })

        case .modificationDateDesc:
            sorted(by: { $0.orderedEntry.modifiedTime > $1.orderedEntry.modifiedTime })
        }
    }
}
