//
// UseCaseContainer.swift
// Proton Authenticator - Created on 19/02/2025.
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

import DomainLayer
import Factory

final class UseCaseContainer: SharedContainer, AutoRegistering {
    static let shared = UseCaseContainer()
    let manager = ContainerManager()

    func autoRegister() {
        manager.defaultScope = .singleton
    }

    var copyTextToClipboard: Factory<any CopyTextToClipboardUseCase> {
        self { CopyTextToClipboard() }
    }

    var generateEntryUiModels: Factory<any GenerateEntryUiModelsUseCase> {
        self { GenerateEntryUiModels(repository: RepositoryContainer.shared.entryRepository(),
                                     service: ServiceContainer.shared.entryDataService()) }
    }

    var parseImageQRCodeContent: Factory<any ParseImageQRCodeContentUseCase> {
        self { ParseImageQRCodeContent() }
    }
}
