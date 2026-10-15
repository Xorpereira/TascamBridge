//
//  TascamBridgeApp.swift
//  TascamBridge
//
//  Created by Frederico Pereira on 13/10/2026.
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

@main
struct TascamBridgeApp: App {
    @State private var app = AppModel()

    var body: some Scene {
        WindowGroup("Tascam Bridge", id: "main") {
            ContentView(app: app)
        }

        MenuBarExtra {
            MenuBarView(app: app)
        } label: {
            let color: NSColor = app.allConnected ? .systemGreen : .systemRed
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
                .applying(.init(paletteColors: [color]))
            let image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: nil)
            let coloredImage = image?.withSymbolConfiguration(config)

            Image(nsImage: coloredImage ?? NSImage())
        }
    }
}
