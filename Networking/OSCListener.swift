//
//  OSCListener.swift
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
import SwiftOSC

@Observable
final class OSCListener {
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "osc.listener.queue")

    var logMessage: ((String) -> Void)?
    var onOSCReceived: ((String, [OSCArg]) -> Void)?

    // MARK: - Start / Stop

    func start(port: UInt16) {
        stop()

        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            logMessage?("Invalid OSC port: \(port)")
            return
        }

        do {
            let params = NWParameters.udp
            params.allowLocalEndpointReuse = true

            let l = try NWListener(using: params, on: nwPort)
            self.listener = l

            l.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    Task { @MainActor [weak self] in
                        self?.logMessage?("OSC listening on port \(port)")
                    }
                case .failed(let error):
                    Task { @MainActor [weak self] in
                        self?.logMessage?("OSC listener failed: \(error)")
                    }
                default:
                    break
                }
            }

            l.newConnectionHandler = { [weak self] connection in
                connection.start(queue: self?.queue ?? .main)
                self?.receive(on: connection)
            }

            l.start(queue: queue)

        } catch {
            logMessage?("Failed to start OSC listener: \(error)")
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    // MARK: - Receive

    private func receive(on connection: NWConnection) {
        connection.receiveMessage { [weak self] data, _, _, error in
            if let error = error {
                Task { @MainActor [weak self] in
                    self?.logMessage?("OSC receive error: \(error)")
                }
                return
            }

            if let data = data, !data.isEmpty {
                self?.decodePacket(data)
            }

            // Continue listening
            self?.receive(on: connection)
        }
    }

    // MARK: - Decode with SwiftOSC

    private nonisolated func decodePacket(_ data: Data) {
        do {
            let message = try OSCMessage(from: data)
            let address = message.addressPattern.stringValue
            let args = Self.extractArguments(from: message)

            Task { @MainActor [weak self] in
                self?.logMessage?("OSC received: \(address)")
                self?.onOSCReceived?(address, args)
            }
        } catch {
            Task { @MainActor [weak self] in
                self?.logMessage?("OSC decode failed: \(error)")
            }
        }
    }

    private nonisolated static func extractArguments(from message: OSCMessage) -> [OSCArg] {
        var result: [OSCArg] = []

        for value in message.values {
            switch value {
            case let intValue as Int32:
                result.append(.int(intValue))
            case let floatValue as Float32:
                result.append(.float(floatValue))
            case let stringValue as String:
                result.append(.string(stringValue))
            case let doubleValue as Double:
                result.append(.float(Float(doubleValue)))
            case let int64Value as Int64:
                result.append(.int(Int32(int64Value)))
            default:
                result.append(.other)
            }
        }

        return result
    }
}

// MARK: - Internal argument type

enum OSCArg {
    case int(Int32)
    case float(Float)
    case string(String)
    case other

    var intValue: Int? {
        switch self {
        case .int(let v):     return Int(v)
        case .float(let v):   return Int(v)
        case .string(let s):  return Int(s)
        case .other:          return nil
        }
    }

    var stringValue: String? {
        switch self {
        case .string(let s):  return s
        case .int(let v):     return String(v)
        case .float(let v):   return String(v)
        case .other:          return nil
        }
    }
}
