//
//  SS.swift
//  TascamBridge
//
//  Created by Frederico Pereira on 06/10/2026.
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

struct SS_R250N: TascamDevice {
    static let displayName = "SS-R250N"
    static let loginString: String? = "SS-R250N"

    static func play() -> String {
        return "012"
    }

    static func stop() -> String {
        return "010"
    }

    static func selectTrack(_ trackNumber: Int) -> String? {
        guard (0...9999).contains(trackNumber) else { return nil }

        let padded = String(format: "%04d", trackNumber)
        let thousands = padded[padded.index(padded.startIndex, offsetBy: 0)]
        let hundreds  = padded[padded.index(padded.startIndex, offsetBy: 1)]
        let tens      = padded[padded.index(padded.startIndex, offsetBy: 2)]
        let ones      = padded[padded.index(padded.startIndex, offsetBy: 3)]

        // Command 23 + Data(Tens, Ones, Thousands, Hundreds), with ID prefix 0
        return "023\(tens)\(ones)\(thousands)\(hundreds)"
    }

    static func keepAlive() -> String {
        return "00F"
    }
}
