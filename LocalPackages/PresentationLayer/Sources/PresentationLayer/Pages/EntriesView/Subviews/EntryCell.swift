//
// EntryCell.swift
// Proton Authenticator - Created on 11/02/2025.
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

import Combine
import DataLayer
import Factory
import Models
import SwiftUI

struct EntryCell: View {
    @State private var viewModel: EntryCellModel

    init(entry: Entry) {
        _viewModel = .init(wrappedValue: EntryCellModel(entry: entry))
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                HStack(alignment: .center, spacing: 10) {}
                    .padding(.horizontal, 5)
                    .padding(.vertical, 4)
                    .frame(width: 32, height: 32, alignment: .center)
                    .background(.black.opacity(0.16))
                    .cornerRadius(8)
                    .shadow(color: .white.opacity(0.1), radius: 1, x: 0, y: 1)
                    .overlay(RoundedRectangle(cornerRadius: 8)
                        .inset(by: -0.5)
                        .stroke(.black.opacity(0.23), lineWidth: 1))

                VStack(alignment: .leading) {
                    Text(viewModel.entry.name)
                        .font(Font.custom("SF Pro Text", size: 18)
                            .weight(.medium))
                        .foregroundStyle(.textNorm)
                    Text(viewModel.entry.uri)
                        .foregroundStyle(.textWeak)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                CircularProgressView(progress: viewModel.progress, countdown: viewModel.countdown)
            }
            .padding(.top, 13)
            .padding(.horizontal, 16)

            Divider()
                .shadow(color: .black.opacity(0.2), radius: 0, x: 0, y: -1)

            HStack {
                ForEach(Array(viewModel.code.current.enumerated()), id: \.offset) { _, char in
                    HStack(alignment: .center, spacing: 10) {
                        Text("\(char)")
                            .font(Font.custom("SF Mono", size: 28)
                                .weight(.semibold))
                            .foregroundStyle(.textNorm)
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.16))
                    .cornerRadius(8)
                    .shadow(color: .white.opacity(0.1), radius: 1, x: 0, y: 1)
                    .overlay(RoundedRectangle(cornerRadius: 8)
                        .inset(by: -0.5)
                        .stroke(.black.opacity(0.23), lineWidth: 1))
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Next")
                        .foregroundStyle(.textWeak)
                    Text(viewModel.code.next)
                        .foregroundStyle(.textNorm)
                        .fontWeight(.semibold)
                }
            }
            .padding(.bottom, 13)
            .padding(.horizontal, 16)
        }
        // TODO: find a workaround for < iOS 18
        /*
         .onScrollVisibilityChange(threshold: 0) { visible in
             viewModel.update = visible
             if visible {
                 viewModel.updateTOTP()
             }
         }
          */
        .background(.purple)
        .cornerRadius(18)
        .shadow(color: .black.opacity(0.16), radius: 4, x: 0, y: 2)
        .overlay(RoundedRectangle(cornerRadius: 18)
            .inset(by: 0.5)
            .stroke(Color(red: 0.92, green: 0.92, blue: 0.92).opacity(0.5), lineWidth: 1))
        .task {
            viewModel.updateTOTP()
        }
        .onTapGesture {
            viewModel.copyToClipboard()
        }
        //                        .simultaneousGesture(onTapGesture {
        //                            viewModel.copyToClipboard(code: token.totp)
        //                        })
    }
}

#Preview {
    EntryCell(entry: Entry(name: "This is the name",
                           uri: "plop@plop.com",
                           period: 30,
                           type: .totp,
                           note: nil))
}

@MainActor
@Observable
private final class EntryCellModel {
    private(set) var code: Code = .default
    private(set) var remainingTime: TimeInterval = 0
    private(set) var progress: Double = 1.0
    private(set) var countdown: Int = 0

    let entry: Entry

    @ObservationIgnored
    private var cancellables = Set<AnyCancellable>()
    @ObservationIgnored
    var update = true
    @ObservationIgnored
    @LazyInjected(\ServiceContainer.timerService) private(set) var timerService
    @ObservationIgnored
    @LazyInjected(\RepositoryContainer.entryRepository) private(set) var entryRepository

    init(entry: Entry) {
        self.entry = entry
        code = getCode()
        setup()
    }
}

private extension EntryCellModel {
    func updateTOTP() {
        let remaining = entry.remainingTime
        remainingTime = remaining > 0 ? remaining : Double(entry.period)
        if remainingTime >= Double(entry.period) - 1 {
            // Code has expired, generate a new one
            code = getCode()
        }
        progress = remainingTime / Double(entry.period)
        // Delayed countdown logic
        countdown = Int(remainingTime)
    }

    func setup() {
        timerService.timer
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, update else { return }
                updateTOTP()
            }
            .store(in: &cancellables)
    }

    func copyToClipboard() {
        // TODO: Take into account user settings (expiration, share with other devices...)
        let pasteboard = UIPasteboard.general
        pasteboard.string = code.current
    }

    func getCode() -> Code {
        // TODO: Handle error
        (try? entryRepository.generateCodes(entries: [entry]).first) ??
            Code.default
    }
}

private struct CircularProgressView: View {
    let progress: Double // Progress between 0 and 1
    let countdown: Int
    let size: CGFloat // Diameter of the circle
    let lineWidth: CGFloat // Thickness of the progress bar

    init(progress: Double, countdown: Int, size: CGFloat = 32, lineWidth: CGFloat = 4) {
        self.progress = progress
        self.countdown = countdown
        self.size = size
        self.lineWidth = lineWidth
    }

    var body: some View {
        ZStack {
            // Background Circle
            Circle()
                .stroke(progressColor.opacity(0.3),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .frame(width: size, height: size)

            // Progress Circle
            Circle()
                .trim(from: 1 - progress, to: 1)
                .stroke(progressColor,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: size, height: size)

            // Timer Text
            Text("\(countdown)")
                .font(.caption)
                .foregroundStyle(.textNorm)
                .monospacedDigit()
        }
        .animation(.default, value: progress)
    }

    var progressColor: Color {
        switch progress {
        case 0.0...0.08:
            .timerLevel1
        case 0.08...0.16:
            .timerLevel2
        case 0.16...0.25:
            .timerLevel3
        case 0.25...0.33:
            .timerLevel4
        case 0.33...0.4:
            .timerLevel5
        default:
            .timerLevel6
        }
    }
}
