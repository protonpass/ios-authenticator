//
// RetryErrorView.swift
// Proton Authenticator - Created on 25/07/2025.
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

import SwiftUI

struct RetryErrorView: View {
    private let tintColor: Color
    private let error: any Error
    private let onRetry: () -> Void

    init(tintColor: Color,
         error: any Error,
         onRetry: @escaping () -> Void) {
        self.tintColor = tintColor
        self.error = error
        self.onRetry = onRetry
    }

    var body: some View {
        ScrollView {
            VStack {
                Text(verbatim: error.localizedDebugDescription)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.textNorm)
                retryButton
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private extension RetryErrorView {
    var retryButton: some View {
        Button { onRetry() } label: {
            Label("Retry", systemImage: "arrow.counterclockwise")
                .foregroundStyle(tintColor)
        }
    }
}

private extension Error {
    var localizedDebugDescription: String {
        if let debugDescription = (self as? CustomDebugStringConvertible)?.debugDescription,
           debugDescription != localizedDescription {
            "\(localizedDescription) \(debugDescription)"
        } else {
            localizedDescription
        }
    }
}
