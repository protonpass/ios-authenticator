//
// RetryableErrorView.swift
// Proton Authenticator - Created on 04/03/2025.
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

import Macro
import SwiftUI

struct RetryableErrorView: View {
    let mode: Mode
    let tintColor: Color
    let error: any Error
    let onRetry: () -> Void

    enum Mode: Sendable {
        /// Full-page error view, error message displayed  with retry button below
        case vertical(textColor: Color)
        /// Inlined error view, error message displayed with retry button on the right
        case horizontal(textColor: Color)

        public static var defaultVertical: Mode {
            .vertical(textColor: .textNorm)
        }

        public static var defaultHorizontal: Mode {
            .horizontal(textColor: .textNorm)
        }
    }

    init(mode: Mode = .defaultVertical,
         tintColor: Color,
         error: any Error,
         onRetry: @escaping () -> Void) {
        self.mode = mode
        self.tintColor = tintColor
        self.error = error
        self.onRetry = onRetry
    }

    var body: some View {
        switch mode {
        case let .vertical(textColor):
            VStack {
                Text(verbatim: error.localizedDebugDescription)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(textColor)
                retryButton
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case let .horizontal(textColor):
            HStack {
                Text(verbatim: error.localizedDebugDescription)
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(textColor)
                Spacer()
                retryButton
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private extension RetryableErrorView {
    var retryButton: some View {
        Button { onRetry() } label: {
            Label(#localized("Retry", bundle: .module), systemImage: "arrow.counterclockwise")
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
