//
//  MenuBarView.swift
//  TascamBridge
//
//  Created by Frederico Pereira on 13/10/2026.
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

struct MenuBarView: View {
    @Bindable var app: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            HStack {
                Circle()
                    .fill(app.allConnected ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
                Text(app.connectionSummary)
                    .font(.headline)
            }

            Divider()

            ForEach(app.players) { player in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Circle()
                            .fill(player.isConnected ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(player.name)
                            .font(.subheadline)
                        Spacer()
                        Text(player.selectedDevice.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Button("Play") { player.sendPlay() }
                            .disabled(!player.isConnected)
                        Button("Stop") { player.sendStop() }
                            .disabled(!player.isConnected)
                    }
                    .controlSize(.small)
                }
            }

            Divider()

            Button("Show Window") {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding()
        .frame(minWidth: 220)
    }
}
