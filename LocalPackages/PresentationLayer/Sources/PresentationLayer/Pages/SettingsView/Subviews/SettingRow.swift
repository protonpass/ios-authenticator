//
// SettingRow.swift
// Proton Authenticator - Created on 21/02/2025.
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

import SwiftUI

struct SettingRow: View {
    var icon: ImageResource?
    let title: TextContent
    var subtitle: LocalizedStringKey?
    let trailingMode: TrailingMode

    enum TrailingMode {
        case toggle(isOn: Bool, onToggle: () -> Void)
        case chevron(onTap: () -> Void)
        case detailChevron(TextContent, onTap: () -> Void)

        var onTap: (() -> Void)? {
            switch self {
            case let .chevron(onTap):
                onTap
            case let .detailChevron(_, onTap):
                onTap
            default:
                nil
            }
        }
    }

    var body: some View {
        HStack {
            if let icon {
                Image(icon)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 24)
            }

            VStack(alignment: .leading) {
                Text(title)
                    .foregroundStyle(.textNorm)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

                if let subtitle {
                    Text(subtitle)
                        .font(.callout)
                        .foregroundStyle(.textWeak)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)

            Spacer()

            switch trailingMode {
            case let .toggle(isOn, onToggle):
                StaticToggle(isOn: isOn, label: { EmptyView() }, onToggle: onToggle)
                    .fixedSize(horizontal: true, vertical: false)

            case .chevron:
                Image(systemName: "chevron.right")
                    .foregroundStyle(.textWeak)

            case let .detailChevron(detail, _):
                Text(detail)
                    .foregroundStyle(.textNorm)

                Image(systemName: "chevron.right")
                    .foregroundStyle(.textWeak)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(.rect)
        .if(trailingMode.onTap) { view, onTap in
            view.onTapGesture(perform: onTap)
        }
    }
}
