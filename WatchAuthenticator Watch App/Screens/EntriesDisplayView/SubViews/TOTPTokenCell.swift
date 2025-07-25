//
// TOTPTokenCell.swift
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

import Foundation
import SwiftUI

struct TOTPTokenCell: View {
    @State private var model: TOTPTokenCellModel

    init(entry: UIModel) {
        _model = State(wrappedValue: TOTPTokenCellModel(entry: entry))
    }

    var period: TimeInterval {
        TimeInterval(model.entry.orderedEntry.entry.period)
    }

    var issuer: String {
        model.entry.orderedEntry.entry.issuer
    }

    var label: String {
        model.entry.orderedEntry.entry.name
    }

    var textColor: Color {
        Color(red: 0.87, green: 0.87, blue: 0.87)
    }

    var body: some View {
        VStack {
            VStack(alignment: .leading) {
                Text(verbatim: issuer)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(textColor)
                Text(verbatim: label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(textColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let code = model.code {
                Text(verbatim: code.mainCode)
                    .font(.title2)
                    .monospaced()
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)
            }
            TimelineView(.animation(minimumInterval: 1.0 / period)) { context in
                let progress = computeProgress(current: context.date, period: period)

                ProgressView(value: progress)
                    .progressViewStyle(RoundedRectProgressViewStyle())
            }
        }
        .padding(.vertical, 8)
    }

    @MainActor
    private func computeProgress(current: Date, period: TimeInterval) -> Double {
        let elapsed = current.timeIntervalSince1970.truncatingRemainder(dividingBy: period)
        let progress = min(max(elapsed / period, 0), 1)
        if progress < 0.01 {
            model.updateCode()
        }

        return progress
    }
}

@Observable
@MainActor
final class TOTPTokenCellModel {
    var code: String?

    let entry: UIModel
    private var timer: Timer?

    init(entry: UIModel) {
        self.entry = entry
        updateCode()
    }

    func updateCode() {
        code = entry.token.currentPassword
    }
}

struct RoundedRectProgressViewStyle: ProgressViewStyle {
    func makeBody(configuration: Configuration) -> some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let progress = configuration.fractionCompleted ?? 0

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 16)
                    .frame(height: 4)
                    .foregroundColor(Color.gray.opacity(0.2))

                RoundedRectangle(cornerRadius: 16)
                    .frame(width: width * progress, height: 4)
                    .foregroundColor(progress.color)
            }
        }
        .frame(height: 4)
    }
}

private extension Double {
    var color: Color {
        switch self {
        case 0.9...1:
            .timer1
        case 0.75...0.9:
            .timer2
        default:
            .timer3
        }
    }
}

private extension String {
    var mainCode: String {
        count > 6 ? self : spaced(every: 3)
    }
}

extension String {
    func spaced(every n: Int) -> String {
        guard n > 0 else { return self }

        return stride(from: 0, to: count, by: n).map { index in
            let start = self.index(startIndex, offsetBy: index)
            let end = self.index(start, offsetBy: n, limitedBy: endIndex) ?? endIndex
            return String(self[start..<end])
        }
        .joined(separator: " ")
    }
}
