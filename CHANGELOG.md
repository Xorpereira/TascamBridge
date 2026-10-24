# Changelog

All notable changes to TascamBridge are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned

- Response monitoring from the recorder (read Telnet replies into the log)
- Optional per-player keyboard shortcuts for Play/Stop
- Show-file presets for different venues

## [1.1] - 2026-10-24

### Added

- Command pacing: outgoing Telnet commands are spaced at a minimum 60ms
  interval to prevent dropped commands when QLab fires a rapid burst of cues.
- Track-to-play delay: a 300ms gap is inserted automatically between a track
  selection (`023xxxx`) and a following play (`012`) so the recorder has time
  to finish seeking before playback starts.
- Log pane auto-scrolls to the newest entry.
- Keep-alive timer resets on every valid command, so idle-triggered heartbeats
  only fire during genuine inactivity.

### Changed

- Keep-alive interval increased from 90s to 120s. The SS-R250N's documented
  idle timeout is 3 minutes, so this leaves comfortable margin while reducing
  unnecessary traffic.
- App version bumped to 1.1, build 2.

### Fixed

- Rapid sequential QLab cues (stop → track → play) no longer drop the play
  command. No pre-waits are required in QLab.

## [1.0] - 2026-10-20

### Added

- Initial release.
- Control of TASCAM SS-R250N and HD-R1 over Ethernet via Telnet.
- OSC listener on a configurable UDP port, accepting messages from QLab,
  Resolume, TouchOSC, and any OSC-capable sender.
- Multiple simultaneous players with mixed device types.
- Positional addressing (`/playerN/...`) and named addressing (`/<name>/...`),
  both case-insensitive.
- Typed OSC arguments (integers, floats, strings) via SwiftOSC.
- Track selection by number for the SS-R250N (`023` + digit order).
- Automatic keep-alive to prevent idle Telnet disconnects.
- Auto-reconnect with exponential backoff (2s → 30s cap) on unexpected drops.
- Menu bar icon showing aggregate connection state (green = all connected,
  red = any disconnected).
- Persistent player configuration across launches (`UserDefaults`).
- Shared log pane with per-player prefixes.
- Player name validation: single word, no spaces, no slashes, unique
  (case-insensitive).
- Collapsible player cards in the main window.
- Per-player Play/Stop buttons in both the main window and the menu bar.

[Unreleased]: https://github.com/Xorpereira/TascamBridge/compare/v1.1...HEAD
[1.1]: https://github.com/Xorpereira/TascamBridge/compare/v1.0...v1.1
[1.0]: https://github.com/Xorpereira/TascamBridge/releases/tag/v1.0
