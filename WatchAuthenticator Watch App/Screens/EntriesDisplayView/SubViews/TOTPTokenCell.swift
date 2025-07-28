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

import Combine
import FactoryKit
import Foundation
import SwiftUI

@MainActor
struct TOTPTokenCell: View, @preconcurrency Equatable {
    private let entry: UIModel
    @State private var timerManager = resolve(\WatchDIContainer.countdownTimer)

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

    var textColor: Color {
        Color(red: 0.87, green: 0.87, blue: 0.87)
    }

    var body: some View {
        let progress = timerManager.calculateProgress(period: period)

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

            if let code = entry.token.currentPassword {
                Text(verbatim: code.mainCode)
                    .font(.title2)
                    .monospaced()
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)
            }

            ProgressView(value: 1 - progress)
                .progressViewStyle(RoundedRectProgressViewStyle())
                .animation(.default, value: progress)
                .transaction { transaction in
                    transaction
                        .disablesAnimations = progress >= 0.96 // infos.timeRemaining == Int(Double(period) - 1)
                }
        }
        .padding(.vertical, 8)
    }

    static func == (lhs: TOTPTokenCell, rhs: TOTPTokenCell) -> Bool {
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

@MainActor
public protocol CountdownTimerProtocol: Sendable, Observable {
    func calculateProgress(period: Int) -> Double
}

@MainActor @Observable
public final class CountdownTimer: CountdownTimerProtocol {
    public static let shared = CountdownTimer()

    private var timerCancellable: AnyCancellable?

    private var currentTimestamp: TimeInterval = Date().timeIntervalSince1970

    private init() {
        startTimer()
    }

    public func startTimer() {
        guard timerCancellable == nil else { return }

        timerCancellable = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                currentTimestamp = Date().timeIntervalSince1970
            }
    }

    public func calculateProgress(period: Int) -> Double {
        (Double(period) - currentTimestamp.truncatingRemainder(dividingBy: Double(period))) / Double(period)
    }
}
