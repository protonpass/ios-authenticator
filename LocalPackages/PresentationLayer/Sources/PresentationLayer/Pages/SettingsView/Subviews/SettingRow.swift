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

import Models
import SwiftUI

struct SettingRow: View {
    var icon: ImageResource?
    let title: TextContent
    var subtitle: LocalizedStringKey?
    var trailingMode: TrailingMode?
    var onTap: (() -> Void)?

    enum TrailingMode {
        case toggle(isOn: Bool, onToggle: () -> Void)
        case detailChevronUpDown(TextContent)
    }

    var body: some View {
        HStack(spacing: 0) {
            if let icon {
                Image(icon)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 22)
                    .padding(6)
                    .padding(.trailing, DesignConstant.padding)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(.textNorm)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

                if let subtitle {
                    Text(subtitle, bundle: .module)
                        .font(.callout)
                        .foregroundStyle(.textWeak)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)

            if let trailingMode {
                Spacer()

                switch trailingMode {
                case let .toggle(isOn, onToggle):
                    StaticToggle(isOn: isOn, label: { EmptyView() }, onToggle: onToggle)
                        .fixedSize(horizontal: true, vertical: false)

                case let .detailChevronUpDown(detail):
                    Text(detail)
                        .foregroundStyle(.textNorm)
                        .padding(.trailing, DesignConstant.padding / 2)

                    Image(systemName: "chevron.up.chevron.down")
                        .foregroundStyle(.textNorm)
                }
            }
        }
        .padding(DesignConstant.padding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(.rect)
        .if(onTap) { view, onTap in
            view.onTapGesture(perform: onTap)
        }
    }
}
