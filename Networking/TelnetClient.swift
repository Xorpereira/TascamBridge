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
    private let minimumCommandInterval: TimeInterval = 0.06 // 60ms

    // Keep-alive
    private var keepAliveTimer: DispatchSourceTimer?
    private var keepAliveCommand: String = ""
    private let keepAliveInterval: TimeInterval = 120 // increased from 90s

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
            self.sendCommandInternal(self.keepAliveCommand, isKeepAlive: true)
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

    /// Resets the keep-alive timer's deadline to now + interval.
    private func resetKeepAlive() {
        guard keepAliveTimer != nil else { return }
        keepAliveTimer?.schedule(deadline: .now() + keepAliveInterval, repeating: keepAliveInterval)
    }

    // MARK: - Send (paced)

    /// Public entry point. Enforces minimum spacing between commands.
    func sendCommand(_ command: String) {
        guard isConnected else {
            logMessage?("Cannot send — not connected")
            return
        }

        sendQueue.async { [weak self] in
            guard let self = self else { return }

            let now = Date()
            let elapsed = now.timeIntervalSince(self.lastSendTime)

            if elapsed < self.minimumCommandInterval {
                let wait = self.minimumCommandInterval - elapsed
                Thread.sleep(forTimeInterval: wait)
            }

            self.lastSendTime = Date()
            self.sendRaw("\(command)\r\n")
            self.logMessage?("Sent: \(command)")

            // Any valid command resets the keep-alive timer
            DispatchQueue.main.async {
                self.resetKeepAlive()
            }
        }
    }

    /// Internal send that bypasses pacing (used for keep-alive, which is already sparse).
    private func sendCommandInternal(_ command: String, isKeepAlive: Bool) {
        sendRaw("\(command)\r\n")
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
