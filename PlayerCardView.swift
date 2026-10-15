//
//  PlayerCardView.swift
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

struct PlayerCardView: View {
    @Bindable var player: PlayerModel
    var app: AppModel
    var onRemove: () -> Void

    @State private var draftName: String = ""
    @FocusState private var nameFieldFocused: Bool

    /// Live validation of the draft name — used for the red border and tooltip.
    private var draftError: String? {
        app.nameValidationError(draftName, excluding: player)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            HStack {
                Button {
                    player.isExpanded.toggle()
                } label: {
                    Image(systemName: player.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                }
                .buttonStyle(.plain)

                Circle()
                    .fill(player.isConnected ? Color.green : Color.red)
                    .frame(width: 10, height: 10)

                TextField("player name", text: $draftName)
                    .textFieldStyle(.plain)
                    .font(.headline)
                    .frame(maxWidth: 140, alignment: .leading)
                    .focused($nameFieldFocused)
                    .foregroundStyle(draftError == nil ? Color.primary : Color.red)
                    .help("Use a single word, no spaces or '/'. Must be unique. OSC commands can use this name case-insensitively, e.g. /\(draftName.isEmpty ? "main" : draftName.lowercased())/play")
                    .onAppear { draftName = player.name }
                    .onChange(of: player.name) { _, newValue in
                        if !nameFieldFocused { draftName = newValue }
                    }
                    .onSubmit { commitName() }
                    .onChange(of: nameFieldFocused) { _, focused in
                        if !focused { commitName() }
                    }

                Text(player.selectedDevice.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(player.statusText)
                    .font(.caption)
                    .foregroundStyle(player.isConnected ? Color.green : Color.secondary)

                Button(role: .destructive) {
                    onRemove()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }

            if player.isExpanded {
                Divider()

                HStack {
                    Text("Device:")
                        .frame(width: 70, alignment: .trailing)
                    Picker("", selection: $player.selectedDevice) {
                        ForEach(PlayerModel.DeviceType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                HStack {
                    Text("IP:")
                        .frame(width: 70, alignment: .trailing)
                    TextField("192.168.1.100", text: $player.deviceIP)
                        .textFieldStyle(.roundedBorder)
                }

                HStack {
                    Text("Port:")
                        .frame(width: 70, alignment: .trailing)
                    TextField("23", text: $player.devicePort)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    Spacer()
                }

                HStack {
                    Button("Connect") { player.connect() }
                        .buttonStyle(.borderedProminent)
                    Button("Disconnect") { player.disconnect() }
                    Spacer()
                    Button("Play") { player.sendPlay() }
                    Button("Stop") { player.sendStop() }
                }
                .padding(.top, 4)
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }

    private func commitName() {
        if app.rename(player, to: draftName) {
            draftName = player.name
        } else {
            // Revert to the last valid name
            draftName = player.name
        }
    }
}
