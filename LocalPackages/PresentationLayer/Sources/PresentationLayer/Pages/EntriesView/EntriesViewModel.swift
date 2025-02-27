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
import Factory
import Foundation
import Models

@Observable
@MainActor
final class EntriesViewModel {
    private(set) var uiModels: [EntryUiModel] = []
    var search = ""

    @ObservationIgnored
    private var pauseRefreshing = false

    @ObservationIgnored
    private var entries: [Entry] = []

    @ObservationIgnored
    private let bundle: Bundle

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.settingsService)
    private var settingsService

    @ObservationIgnored
    @LazyInjected(\ServiceContainer.qaService)
    private var qaService

    @ObservationIgnored
    @LazyInjected(\UseCaseContainer.copyTextToClipboard)
    private var copyTextToClipboard

    @ObservationIgnored
    @LazyInjected(\UseCaseContainer.generateEntryUiModels)
    private var generateEntryUiModels

    @ObservationIgnored
    private var cancellable: (any Cancellable)?

    @ObservationIgnored
    private var generateTokensTask: Task<Void, Never>?

    init(bundle: Bundle = .main) {
        self.bundle = bundle
        cancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, !pauseRefreshing else {
                    return
                }
                refreshTokens()
            }
    }
}

extension EntriesViewModel {
    func setUp() async {
        do {
            entries = if let mocked = mockedEntries() {
                mocked
            } else {
                try await getEntries()
            }
        } catch {
            handle(error)
        }
    }

    func refreshTokens() {
        generateTokensTask?.cancel()
        generateTokensTask = Task { [weak self] in
            guard let self else { return }
            do {
                uiModels = try await generateEntryUiModels(from: entries, on: .now)
            } catch {
                handle(error)
            }
        }
    }

    func copyTokenToClipboard(_ entry: EntryUiModel) {
        let code = entry.code.current
        assert(!code.isEmpty, "Code should not be empty")
        copyTextToClipboard(code)
    }

    func toggleCodeRefresh(_ shouldPause: Bool) {
        pauseRefreshing = shouldPause
        if !pauseRefreshing {
            refreshTokens()
        }
    }
}

private extension EntriesViewModel {
    func mockedEntries() -> [Entry]? {
        guard bundle.isQaBuild, qaService.showMockEntries else {
            return nil
        }
        let count = max(5, qaService.numberOfMockEntries)

        var entries = [Entry]()
        for index in 0..<count {
            entries.append(.init(name: "Test #\(index)",
                                 uri: "otpauth://totp/SimpleLogin:john.doe\(index)%40example.com?secret=CKTQQJVWT5IXTGD\(index)&amp;issuer=SimpleLogin",
                                 period: 30,
                                 type: .totp,
                                 note: "Note #\(index)"))
        }

        return entries
    }

    func getEntries() async throws -> [Entry] {
        // Get entries from database
        []
    }

    func handle(_ error: any Error) {
        // swiftlint:disable:next todo
        // TODO: Log and display error to the users
        print(error.localizedDescription)
    }
}
