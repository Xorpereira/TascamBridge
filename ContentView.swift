//
//  ContentView.swift
//  TascamBridge
//
//  Created by Frederico Pereira on 14/10/2026.
//
// TascamBridge — OSC to TASCAM recorder bridge
// Copyright (C) 2026 Frederico Pereira
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import SwiftUI

struct ContentView: View {
    @Bindable var app: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            HStack {
                Text("OSC Port:")
                TextField("5005", text: $app.oscPort)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                Spacer()
                Text(app.connectionSummary)
                    .foregroundStyle(app.allConnected ? Color.green : Color.secondary)
                    .font(.headline)
                Button("Add Player") { app.addPlayer() }
                    .buttonStyle(.borderedProminent)
            }

            Divider()

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(app.players) { player in
                        PlayerCardView(player: player, app: app) {
                            app.removePlayer(player)
                        }
                    }
                }
            }
            .frame(minHeight: 220)

            Divider()

            GroupBox("Log") {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(app.logEntries.enumerated()), id: \.offset) { index, entry in
                                Text(entry)
                                    .font(.system(.caption, design: .monospaced))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .id(index)
                            }
                        }
                        .padding(4)
                    }
                    .onChange(of: app.logEntries.count) { _, _ in
                        guard let lastIndex = app.logEntries.indices.last else { return }
                        withAnimation(.easeOut(duration: 0.15)) {
                            proxy.scrollTo(lastIndex, anchor: .bottom)
                        }
                    }
                }
                .frame(minHeight: 140)
            }
        }
        .padding()
        .frame(minWidth: 560, minHeight: 620)
    }
}
