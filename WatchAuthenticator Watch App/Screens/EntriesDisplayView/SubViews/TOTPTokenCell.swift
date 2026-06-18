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

import CommonUtilities
import Foundation
import SwiftUI

struct TOTPTokenCell: View, @preconcurrency Equatable {
    private let entry: UIModel

    init(entry: UIModel) {
        self.entry = entry
    }

    var period: Int {
        entry.orderedEntry.entry.period
    }

    var issuer: String {
        entry.orderedEntry.entry.issuer
    }

    var label: String {
        entry.orderedEntry.entry.name
    }

    var body: some View {
        VStack {
            VStack(alignment: .leading) {
                Text(verbatim: issuer)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.cellText)
                Text(verbatim: label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.cellText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let code = entry.token.currentPassword {
                Text(verbatim: code.mainCode)
                    .font(.title2)
                    .monospaced()
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)
            }

            // `TimelineView` drives (and pauses, when off-screen) this once-a-second redraw, instead
            // of a shared `@Observable` mutated by a 10x/second `Timer` that re-rendered every cell.
            TimelineView(.periodic(from: nextSecondBoundary, by: 1)) { context in
                let progress = TOTPCountdown.make(at: context.date, period: period).fractionRemaining

                ProgressView(value: 1 - progress)
                    .progressViewStyle(RoundedRectProgressViewStyle())
                    .animation(.default, value: progress)
                    .transaction { transaction in
                        transaction
                            .disablesAnimations = progress >= 0.96
                    }
            }
        }
        .padding(.vertical, 8)
    }

    /// Aligns the timeline to whole-second boundaries so the progress steps exactly on the second.
    private var nextSecondBoundary: Date {
        Date(timeIntervalSince1970: Date.now.timeIntervalSince1970.rounded(.up))
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.entry == rhs.entry
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
                    .foregroundStyle(Color.gray.opacity(0.2))

                RoundedRectangle(cornerRadius: 16)
                    .frame(width: width * progress, height: 4)
                    .foregroundStyle(progress.color)
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
        count > 6 ? self : separatedByGroup(3, delimiter: " ")
    }
}
