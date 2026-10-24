//
//  TelnetClient.swift
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
import Network

@Observable
final class TelnetClient {
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "telnet.client.queue")

    // Command pacing
    private let sendQueue = DispatchQueue(label: "telnet.send.queue")
    private var lastSendTime: Date = .distantPast
    private var lastCommand: String = ""
    private let minimumCommandInterval: TimeInterval = 0.06   // 60ms between any two commands
    private let trackToPlayInterval: TimeInterval = 0.3       // extra wait after a track command

    // Keep-alive
    private var keepAliveTimer: DispatchSourceTimer?
    private var keepAliveCommand: String = ""
    private let keepAliveInterval: TimeInterval = 120

    var isConnected = false
    var logMessage: ((String) -> Void)?
    var onConnectionDropped: (() -> Void)?

    // MARK: - Connect

    func connect(host: String, port: UInt16, loginString: String?, keepAliveCommand: String) {
        disconnect()

        self.keepAliveCommand = keepAliveCommand

        let nwHost = NWEndpoint.Host(host)
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            logMessage?("Invalid port: \(port)")
            return
        }

        let params = NWParameters.tcp
        let conn = NWConnection(host: nwHost, port: nwPort, using: params)
        self.connection = conn

        conn.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.logMessage?("TCP connected to \(host):\(port)")
                self?.isConnected = true
                if let login = loginString {
                    self?.sendLoginHandshake(login)
                } else {
                    self?.logMessage?("Connected (no login required)")
                }
                self?.startKeepAlive()

            case .failed(let error):
                self?.logMessage?("Connection failed: \(error)")
                self?.isConnected = false
                self?.stopKeepAlive()
                self?.onConnectionDropped?()

            case .waiting(let error):
                self?.logMessage?("Waiting: \(error)")

            case .cancelled:
                self?.logMessage?("Connection cancelled")
                self?.isConnected = false
                self?.stopKeepAlive()

            default:
                break
            }
        }

        conn.start(queue: queue)
    }

    // MARK: - Login

    private func sendLoginHandshake(_ login: String) {
        sendRaw("\r\n")
        queue.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.sendRaw("\(login)\r\n")
            self?.logMessage?("Login handshake sent: \(login)")
        }
    }

    // MARK: - Keep-Alive

    private func startKeepAlive() {
        keepAliveTimer?.cancel()
        keepAliveTimer = nil

        guard !keepAliveCommand.isEmpty else {
            logMessage?("Keep-alive skipped (no command for this device)")
            return
        }

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + keepAliveInterval, repeating: keepAliveInterval)
        timer.setEventHandler { [weak self] in
            guard let self = self, self.isConnected else { return }
            self.sendRaw("\(self.keepAliveCommand)\r\n")
            self.logMessage?("Keep-alive sent (\(self.keepAliveCommand))")
        }
        timer.resume()
        keepAliveTimer = timer

        logMessage?("Keep-alive started (every \(Int(keepAliveInterval))s, command: \(keepAliveCommand))")
    }

    private func stopKeepAlive() {
        keepAliveTimer?.cancel()
        keepAliveTimer = nil
    }

    private func resetKeepAlive() {
        guard keepAliveTimer != nil else { return }
        keepAliveTimer?.schedule(deadline: .now() + keepAliveInterval, repeating: keepAliveInterval)
    }

    // MARK: - Send (paced)

    func sendCommand(_ command: String) {
        guard isConnected else {
            logMessage?("Cannot send — not connected")
            return
        }

        sendQueue.async { [weak self] in
            guard let self = self else { return }

            // Determine required gap before this command
            let gap = self.requiredGap(before: command)

            let now = Date()
            let elapsed = now.timeIntervalSince(self.lastSendTime)
            if elapsed < gap {
                let wait = gap - elapsed
                Thread.sleep(forTimeInterval: wait)
            }

            self.lastSendTime = Date()
            self.lastCommand = command
            self.sendRaw("\(command)\r\n")
            self.logMessage?("Sent: \(command)")

            DispatchQueue.main.async {
                self.resetKeepAlive()
            }
        }
    }

    /// Returns the minimum gap required before sending `command`,
    /// based on the previously sent command.
    private func requiredGap(before command: String) -> TimeInterval {
        // After a track selection, play needs extra time for the device to finish seeking.
        if lastCommand.hasPrefix("023") && command == "012" {
            return trackToPlayInterval
        }
        return minimumCommandInterval
    }

    private func sendRaw(_ string: String) {
        guard let data = string.data(using: .utf8) else { return }
        connection?.send(content: data, completion: .contentProcessed { [weak self] error in
            if let error = error {
                self?.logMessage?("Send error: \(error)")
            }
        })
    }

    // MARK: - Disconnect

    func disconnect() {
        stopKeepAlive()
        connection?.cancel()
        connection = nil
        isConnected = false
    }
}
