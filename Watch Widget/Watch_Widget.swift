//
// Watch_Widget.swift
// Proton Authenticator - Created on 02/09/2025.
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
import WidgetKit

private struct DummyEntry: TimelineEntry {
    let date: Date
}

private struct DummyProvider: TimelineProvider {
    func placeholder(in context: Context) -> DummyEntry {
        DummyEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (DummyEntry) -> Void) {
        completion(DummyEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DummyEntry>) -> Void) {
        let entry = DummyEntry(date: .now)
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

@main
struct Watch_Widget: Widget {
    let kind: String = "Watch_Widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DummyProvider()) { _ in
            WidgetContent()
                .containerBackground(for: .widget) {
                    Color.clear
                }
        }
        .supportedFamilies([.accessoryCircular, .accessoryInline, .accessoryRectangular, .accessoryCorner])
    }
}

private struct WidgetContent: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        switch family {
        case .accessoryCircular:
            if renderingMode == .fullColor {
                Image(.authenticator)
                    .padding(6)
                    .background(.background)
            } else {
                Image(.authenticatorGlyph)
            }

        case .accessoryRectangular:
            HStack(alignment: .center) {
                if renderingMode == .fullColor {
                    Image(.authenticator)
                        .padding(6)
                } else {
                    Image(.authenticatorGlyph)
                }

                VStack(alignment: .leading) {
                    Text(verbatim: "Proton")
                        .fontWeight(.medium)
                        .foregroundStyle(.accent)
                    Text(verbatim: "Authenticator")
                }
            }

        case .accessoryInline:
            Text(verbatim: "Proton Authenticator")

        case .accessoryCorner:
            Image(.authenticatorGlyph)
                .widgetLabel {
                    Text(verbatim: "Proton Authenticator")
                        .widgetAccentable()
                }

        @unknown default:
            Text(verbatim: "Proton Authenticator")
        }
    }
}
