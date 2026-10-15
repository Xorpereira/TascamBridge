//
//  PlayerModel.swift
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
final class PlayerModel: Identifiable {

    let id = UUID()
    var name: String {
        didSet { onPersistableChange?() }
    }

    // MARK: - Device selection

    enum DeviceType: String, CaseIterable, Identifiable {
        case ssR250N = "SS-R250N"
        case hdR1 = "HD-R1"

        var id: String { rawValue }

        var device: TascamDevice.Type {
            switch self {
            case .ssR250N: return SS_R250N.self
            case .hdR1:    return HD_R1.self
            }
        }
    }

    var selectedDevice: DeviceType = .ssR250N {
        didSet {
            device = selectedDevice.device
            logMessage?("[\(name)] Switched to \(selectedDevice.rawValue)")
            onPersistableChange?()
        }
    }

    private var device: TascamDevice.Type = SS_R250N.self

    // MARK: - UI State

    var deviceIP: String = "192.168.1.100" {
        didSet { onPersistableChange?() }
    }
    var devicePort: String = "23" {
        didSet { onPersistableChange?() }
    }
    var isExpanded: Bool = true {
        didSet { onPersistableChange?() }
    }

    var statusText: String = "Disconnected"

    var isConnected: Bool {
        statusText == "Connected"
    }

    // MARK: - Services

    private let telnet = TelnetClient()

    /// Set by AppModel so this player can push to the shared log.
    var logMessage: ((String) -> Void)?

    /// Set by AppModel so this player can notify it of persistable field changes.
    var onPersistableChange: (() -> Void)?

    // MARK: - Auto-reconnect state

    private var isManualDisconnect = false
    private var reconnectAttempt = 0
    private var reconnectWorkItem: DispatchWorkItem?

    // MARK: - Init

    init(name: String) {
        self.name = name

        telnet.logMessage = { [weak self] msg in
            guard let self = self else { return }
            DispatchQueue.main.async {
                let wasConnected = self.statusText == "Connected"
                self.logMessage?("[\(self.name)] \(msg)")
                self.statusText = self.telnet.isConnected ? "Connected" : "Disconnected"
                if !wasConnected && self.statusText == "Connected" {
                    // Successful (re)connect — reset backoff
                    self.reconnectAttempt = 0
                }
            }
        }

        telnet.onConnectionDropped = { [weak self] in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.logMessage?("[\(self.name)] Connection dropped unexpectedly")
                self.scheduleReconnect()
            }
        }
    }

    // MARK: - Connection

    func connect() {
        isManualDisconnect = false

        guard let port = UInt16(devicePort), !deviceIP.isEmpty else {
            logMessage?("[\(name)] Invalid IP or port")
            return
        }
        logMessage?("[\(name)] Connecting to \(deviceIP):\(port) as \(device.displayName)...")
        telnet.connect(
            host: deviceIP,
            port: port,
            loginString: device.loginString,
            keepAliveCommand: device.keepAlive()
        )
    }

    func disconnect() {
        isManualDisconnect = true
        cancelReconnect()
        reconnectAttempt = 0
        telnet.disconnect()
        statusText = "Disconnected"
        logMessage?("[\(name)] Disconnected")
    }

    // MARK: - Auto-reconnect

    private func scheduleReconnect() {
        guard !isManualDisconnect else { return }

        let delay = min(pow(2.0, Double(reconnectAttempt)), 30.0)
        reconnectAttempt += 1

        logMessage?("[\(name)] Reconnecting in \(Int(delay))s (attempt \(reconnectAttempt))...")

        let work = DispatchWorkItem { [weak self] in
            guard let self = self, !self.isManualDisconnect else { return }
            self.connect()
        }
        reconnectWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func cancelReconnect() {
        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil
    }

    // MARK: - Commands

    func sendPlay() {
        telnet.sendCommand(device.play())
    }

    func sendStop() {
        telnet.sendCommand(device.stop())
    }

    func sendTrack(_ n: Int) {
        if let cmd = device.selectTrack(n) {
            telnet.sendCommand(cmd)
        } else {
            logMessage?("[\(name)] Track \(n) not supported for \(device.displayName)")
        }
    }

    // MARK: - OSC action handling

    func handleAction(_ action: String, arguments: [OSCArg] = []) {
        switch action {
        case "/play":
            sendPlay()

        case "/stop":
            sendStop()

        case "/track":
            if let trackNum = arguments.first?.intValue {
                sendTrack(trackNum)
            } else {
                logMessage?("[\(name)] /track received but no usable argument")
            }

        case let msg where msg.hasPrefix("/track/"):
            let parts = msg.split(separator: "/", omittingEmptySubsequences: true)
            if let last = parts.last, let trackNum = Int(last) {
                sendTrack(trackNum)
            } else {
                logMessage?("[\(name)] Could not parse track number from \(msg)")
            }

        default:
            let raw = String(action.dropFirst())
            telnet.sendCommand(raw)
        }
    }
}
