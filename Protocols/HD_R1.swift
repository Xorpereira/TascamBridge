//
//  HD.swift
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

struct HD_R1: TascamDevice {
    static let displayName = "HD-R1"
    static let loginString: String? = "Login=HDR1"

    static func play() -> String {
        return "Transport=Play"
    }

    static func stop() -> String {
        return "Transport=Stop"
    }

    static func selectTrack(_ trackNumber: Int) -> String? {
        // HD-R1 uses folder/playlist navigation, not direct track numbers.
        return nil
    }

    static func keepAlive() -> String {
        return "Transport?"
    }
}
