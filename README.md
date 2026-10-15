# TascamBridge

A native macOS app that bridges OSC commands to TASCAM SS-R250N and HD-R1
recorders over Telnet. Designed for live show control from QLab, Resolume,
or any OSC-capable application.

## Overview

TascamBridge listens for OSC messages on a UDP port and translates them
into the Telnet command language understood by TASCAM network-connected
recorders. Multiple recorders can be controlled simultaneously, each with
its own connection, device type, and OSC namespace.

## Features

- Controls **TASCAM SS-R250N** and **HD-R1** over Ethernet
- Accepts OSC messages from any sender (QLab, Resolume, TouchOSC, scripts)
- Multiple players, mixed device types, one shared OSC port
- Each player addressable by position (`/player1/...`) or by name
  (`/main/...`), case-insensitive
- Typed OSC arguments (integers, floats, strings) via SwiftOSC
- Automatic keep-alive to prevent idle Telnet disconnects
- Auto-reconnect with exponential backoff on unexpected drops
- Menu bar icon showing aggregate connection state
- Persistent configuration across launches
- Shared log pane for diagnostics

## Requirements

### To run TascamBridge

- **macOS 14 (Sonoma) or later**
- Network connection to the recorder(s) over Ethernet
- TASCAM SS-R250N firmware V2.15+ (V2.17+ recommended)
- TASCAM HD-R1 with the standard serial protocol firmware

### To build TascamBridge from source

- macOS 14 (Sonoma) or later
- **Xcode 16 or later**
- SwiftOSC package (resolved automatically via Swift Package Manager)

### Why macOS 14

The app relies on several APIs introduced in macOS 14:

- `MenuBarExtra` with modern scene configuration
- `@Observable` macro (Swift Observation framework)
- `@Bindable` property wrapper in SwiftUI views

Lowering the deployment target would require replacing these with
`ObservableObject` / `@Published` and an `NSStatusItem`-based menu bar.

## Building

1. Clone the repository:
   ```
   git clone https://github.com/Xorpereira/TascamBridge.git
   cd TascamBridge
   ```
2. Open `TascamBridge.xcodeproj` in Xcode.
3. Add the SwiftOSC package if not already resolved:
   - File → Add Package Dependencies
   - URL: `https://github.com/orchetect/swift-osc`
   - Version: Up to Next Major
4. Select the `TascamBridge` scheme and build (⌘B).

The project's deployment target is set to **macOS 14.0** in the target's
General settings. Changing this lower will cause build failures on
`@Observable`, `@Bindable`, and `MenuBarExtra`.

### Sandbox / entitlements

The app requires:

- **App Sandbox** enabled
- **Outgoing Connections (Client)** — for Telnet to the recorders
- **Incoming Connections (Server)** — for the OSC UDP listener

For local development you can disable the sandbox entirely; the app runs
fine unsigned in that configuration.

## OSC Command Reference

Every command is prefixed with a player identifier, either positional
(`/playerN`) or by the player's assigned name.

| Command | Arguments | Effect |
|---|---|---|
| `/player1/play` | — | Start playback on player 1 |
| `/player1/stop` | — | Stop playback on player 1 |
| `/player1/track` | integer | Jump to a specific track |
| `/main/play` | — | Play on the player named "main" |
| `/main/track` | integer | Track jump on the named player |
| `/player1/012` | — | Raw passthrough to the SS-R250N |

Addresses are matched **case-insensitively**. `/MAIN/Play` and
`/main/play` are equivalent. Player names are enforced as single words
(no spaces, no `/`) and must be unique.

## Configuration

All state is persisted to `UserDefaults` under the key
`TascamBridge.PersistenceConfig.v1`. Deleting this key resets the app to
defaults.

```
defaults delete xorpereira.tascambridge TascamBridge.PersistenceConfig.v1
```

## Architecture

- `AppModel` — owns the player list, shared OSC listener, shared log,
  persistence, and OSC routing
- `PlayerModel` — one recorder; owns its Telnet connection, keep-alive,
  auto-reconnect, and command dispatch
- `TelnetClient` — TCP connection, login handshake, keep-alive timer
- `OSCListener` — UDP listener using `Network.framework` for transport
  and SwiftOSC for binary decoding
- `TascamDevice` — protocol implemented per device
  (`SS_R250N`, `HD_R1`) that builds the correct command bytes
- `PersistenceConfig` / `PlayerConfig` — Codable snapshots

The UI is SwiftUI: a scrollable list of collapsible `PlayerCardView`
instances, plus a shared log pane and a `MenuBarExtra` for quick access.

## Adding a New Device

1. Create a new Swift file in `Protocols/` conforming to `TascamDevice`.
2. Implement `displayName`, `loginString`, `play()`, `stop()`,
   `selectTrack(_:)`, and `keepAlive()`.
3. Add a case to `PlayerModel.DeviceType` pointing at the new type.

No other changes are needed — routing, persistence, UI, and log all
work generically.

## Known Limitations

- OSC bundles with time tags are decoded but not scheduled; messages
  execute immediately on arrival.
- The HD-R1 does not support direct track-number selection; only
  transport, folder, and playlist commands are exposed.
- Track numbering for the SS-R250N uses the TASCAM-specified digit
  order (tens, ones, thousands, hundreds).

## License

Copyright (C) 2026 Frederico Pereira

This program is free software: you can redistribute it and/or modify it
under the terms of the **GNU Affero General Public License** as published
by the Free Software Foundation, either version 3 of the License, or (at
your option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero
General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program. If not, see <https://www.gnu.org/licenses/>.

### What AGPL means for this project

The AGPL is a strong copyleft license. In practical terms:

- You are free to use, modify, and distribute this software.
- If you distribute a modified version, you must release the source under
  the same license.
- **Network use counts as distribution**: if you run a modified version
  as a network service that others interact with, you must offer them the
  corresponding source code.

The full license text should be included in a `LICENSE` file at the root
of the repository.

## Acknowledgements

Built with [SwiftOSC](https://github.com/orchetect/swift-osc).
Protocol details from TASCAM's published RS-232C/Telnet documentation.
