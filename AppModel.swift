//
//  AppModel.swift
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
import SwiftUI

@Observable
final class AppModel {

    // MARK: - Players

    var players: [PlayerModel] = []
    private var nextPlayerNumber: Int = 1

    // MARK: - OSC

    var oscPort: String = "5005" {
        didSet {
            restartOSC()
            saveState()
        }
    }
    private let osc = OSCListener()

    // MARK: - Shared Log

    var logEntries: [String] = []

    // MARK: - Aggregate state for menu bar icon

    var allConnected: Bool {
        !players.isEmpty && players.allSatisfy { $0.isConnected }
    }

    var anyConnected: Bool {
        players.contains { $0.isConnected }
    }

    var connectionSummary: String {
        let total = players.count
        let connected = players.filter { $0.isConnected }.count
        if total == 0 { return "No players" }
        return "\(connected)/\(total) connected"
    }

    // MARK: - Init

    init() {
        if let saved = Self.loadState() {
            oscPort = saved.oscPort
            for config in saved.players {
                let player = makePlayer(from: config)
                players.append(player)
            }

            // Advance nextPlayerNumber past any existing "playerN" names
            let maxN = saved.players.compactMap { cfg -> Int? in
                guard cfg.name.hasPrefix("player") else { return nil }
                return Int(cfg.name.dropFirst("player".count))
            }.max() ?? 0
            nextPlayerNumber = maxN + 1

            logEntries.append("[\(Self.timestamp())] Restored \(players.count) player(s)")
        } else {
            addPlayer()
        }

        startOSC()
    }

    // MARK: - Player management

    func addPlayer() {
        let base = "player\(nextPlayerNumber)"
        nextPlayerNumber += 1

        var candidate = base
        var suffix = 2
        while !isNameAvailable(candidate) {
            candidate = "\(base)_\(suffix)"
            suffix += 1
        }

        let player = makePlayer(named: candidate)
        players.append(player)
        appendLog("Added \(candidate)")
        saveState()
    }

    func removePlayer(_ player: PlayerModel) {
        player.disconnect()
        players.removeAll { $0 === player }
        appendLog("Removed \(player.name)")
        saveState()
    }

    /// Creates a fresh player wired into the shared log and persistence.
    private func makePlayer(named name: String) -> PlayerModel {
        let player = PlayerModel(name: name)
        wire(player)
        return player
    }

    /// Rebuilds a player from a persisted config.
    private func makePlayer(from config: PlayerConfig) -> PlayerModel {
        let player = PlayerModel(name: config.name)
        if let type = PlayerModel.DeviceType(rawValue: config.deviceType) {
            player.selectedDevice = type
        }
        player.deviceIP = config.deviceIP
        player.devicePort = config.devicePort
        player.isExpanded = config.isExpanded
        wire(player)
        return player
    }

    /// Shared setup for both fresh and restored players.
    private func wire(_ player: PlayerModel) {
        player.logMessage = { [weak self] msg in
            DispatchQueue.main.async {
                self?.appendLog(msg)
            }
        }
        player.onPersistableChange = { [weak self] in
            self?.saveState()
        }
    }

    // MARK: - Name validation

    func nameValidationError(_ name: String, excluding: PlayerModel? = nil) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty {
            return "Name cannot be empty."
        }
        if trimmed.contains("/") {
            return "Name cannot contain '/'."
        }
        if trimmed.contains(where: { $0.isWhitespace }) {
            return "Name cannot contain spaces."
        }

        let lower = trimmed.lowercased()
        let conflict = players.contains { p in
            p !== excluding && p.name.lowercased() == lower
        }
        if conflict {
            return "Name '\(trimmed)' is already in use."
        }
        return nil
    }

    func isNameAvailable(_ name: String, excluding: PlayerModel? = nil) -> Bool {
        nameValidationError(name, excluding: excluding) == nil
    }

    @discardableResult
    func rename(_ player: PlayerModel, to newName: String) -> Bool {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)

        if let error = nameValidationError(trimmed, excluding: player) {
            appendLog("Rename rejected: \(error)")
            return false
        }

        let old = player.name
        player.name = trimmed
        appendLog("Renamed \(old) → \(trimmed)")
        saveState()
        return true
    }

    // MARK: - OSC

    private func startOSC() {
        guard let port = UInt16(oscPort) else {
            appendLog("Invalid OSC port: \(oscPort)")
            return
        }
        osc.logMessage = { [weak self] msg in
            DispatchQueue.main.async {
                self?.appendLog("[OSC] \(msg)")
            }
        }
        osc.onOSCReceived = { [weak self] address, args in
            self?.routeOSC(address, arguments: args)
        }
        osc.start(port: port)
    }

    private func restartOSC() {
        osc.stop()
        startOSC()
    }

    private func routeOSC(_ rawAddress: String, arguments: [OSCArg]) {
        let address = rawAddress.lowercased()

        let parts = address.split(separator: "/", omittingEmptySubsequences: true)
        guard parts.count >= 2 else {
            appendLog("Malformed OSC: \(rawAddress)")
            return
        }

        let token = String(parts[0])
        let target: PlayerModel?

        if token.hasPrefix("player"),
           let n = Int(token.dropFirst("player".count)),
           n >= 1, n <= players.count {
            target = players[n - 1]
        } else {
            target = players.first { $0.name.lowercased() == token }
        }

        guard let player = target else {
            appendLog("Unknown player in OSC: \(rawAddress)")
            return
        }

        let action = "/" + parts.dropFirst().joined(separator: "/")
        player.handleAction(action, arguments: arguments)
    }

    // MARK: - Persistence

    private static func loadState() -> PersistenceConfig? {
        guard let data = UserDefaults.standard.data(forKey: PersistenceConfig.defaultsKey) else {
            return nil
        }
        do {
            return try JSONDecoder().decode(PersistenceConfig.self, from: data)
        } catch {
            return nil
        }
    }

    func saveState() {
        let config = PersistenceConfig(
            oscPort: oscPort,
            players: players.map { player in
                PlayerConfig(
                    name: player.name,
                    deviceType: player.selectedDevice.rawValue,
                    deviceIP: player.deviceIP,
                    devicePort: player.devicePort,
                    isExpanded: player.isExpanded
                )
            }
        )
        do {
            let data = try JSONEncoder().encode(config)
            UserDefaults.standard.set(data, forKey: PersistenceConfig.defaultsKey)
        } catch {
            appendLog("Failed to save state: \(error)")
        }
    }

    // MARK: - Log

    func appendLog(_ entry: String) {
        logEntries.append("[\(Self.timestamp())] \(entry)")
        if logEntries.count > 400 {
            logEntries.removeFirst(logEntries.count - 400)
        }
    }

    private static func timestamp() -> String {
        DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
    }
}
