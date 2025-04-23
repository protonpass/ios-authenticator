//
// TotpGenerator.swift
// Proton Authenticator - Created on 24/03/2025.
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

import AuthenticatorRustCore
import Combine
import Models

public protocol TotpGeneratorProtocol: Sendable {
    var currentCode: CurrentValueSubject<[Code]?, Never> { get }

    func totpUpdate(_ entries: [Entry]) async throws
    func stopUpdating() async
}

public actor TotpGenerator: TotpGeneratorProtocol {
    private let rustTotpGenerator: any MobileTotpGeneratorProtocol
    private var cancellableGenerator: (any MobileTotpGenerationHandle)?

    public nonisolated let currentCode: CurrentValueSubject<[Code]?, Never> = .init(nil)

    public init(rustTotpGenerator: any MobileTotpGeneratorProtocol) {
        self.rustTotpGenerator = rustTotpGenerator
    }

    deinit {
        cancellableGenerator?.cancel()
        cancellableGenerator = nil
    }

    public func totpUpdate(_ entries: [Entry]) async throws {
        cancellableGenerator?.cancel()
        cancellableGenerator = nil

        cancellableGenerator = try rustTotpGenerator.start(entries: entries.toRustEntries, callback: self)
    }

    public func stopUpdating() async {
        cancellableGenerator?.cancel()
        cancellableGenerator = nil
    }
}

extension TotpGenerator: MobileTotpGeneratorCallback {
    public nonisolated func onCodes(codes: [AuthenticatorCodeResponse]) {
        currentCode.send(codes.map(\.toCode))
    }
}

extension CurrentValueSubject: @unchecked @retroactive Sendable {}
