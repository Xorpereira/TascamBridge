//
//  PersistenceConfig.swift
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

import Foundation

/// Snapshot of the app's persisted state.
struct PersistenceConfig: Codable {
    var oscPort: String
    var players: [PlayerConfig]

    static let defaultsKey = "TascamBridge.PersistenceConfig.v1"

    static let `default` = PersistenceConfig(
        oscPort: "5005",
        players: []
    )
}

/// Snapshot of a single player's configuration.
struct PlayerConfig: Codable {
    var name: String
    var deviceType: String      // rawValue of PlayerModel.DeviceType
    var deviceIP: String
    var devicePort: String
    var isExpanded: Bool

    // Note: we deliberately do NOT persist `statusText` or the TCP connection.
    // On launch, all players start disconnected.
}
