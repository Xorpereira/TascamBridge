//
//  NetworkInfo.swift
//  TascamBridge
//
//  Created by Frederico Pereira on 31/10/2026.
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
import Darwin

enum NetworkInfo {
    /// Returns the first active IPv4 address on a non-loopback interface,
    /// or nil if none is found.
    static func localIPv4Address() -> String? {
        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0, let first = ifaddrPtr else {
            return nil
        }
        defer { freeifaddrs(ifaddrPtr) }

        var best: String?
        var current: UnsafeMutablePointer<ifaddrs>? = first

        while let ifa = current {
            let addr = ifa.pointee.ifa_addr
            if let addr = addr, addr.pointee.sa_family == UInt8(AF_INET) {
                let flags = Int32(ifa.pointee.ifa_flags)
                let isUp = (flags & IFF_UP) == IFF_UP
                let isLoopback = (flags & IFF_LOOPBACK) == IFF_LOOPBACK

                if isUp && !isLoopback {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    let result = getnameinfo(
                        addr,
                        socklen_t(addr.pointee.sa_len),
                        &hostname,
                        socklen_t(hostname.count),
                        nil,
                        0,
                        NI_NUMERICHOST
                    )
                    if result == 0 {
                        let ip = String(cString: hostname)
                        // Prefer en0/en1 (Wi-Fi / Ethernet) over other interfaces
                        let ifName = String(cString: ifa.pointee.ifa_name)
                        if ifName.hasPrefix("en") {
                            return ip
                        }
                        if best == nil {
                            best = ip
                        }
                    }
                }
            }
            current = ifa.pointee.ifa_next
        }

        return best
    }
}
