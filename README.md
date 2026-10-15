# # TascamBridge — User Manual

Version 1.0 · https://github.com/Xorpereira/TascamBridge

## What This App Does

TascamBridge lets you control TASCAM SS-R250N and HD-R1 recorders from
any application that can send OSC — most commonly QLab, but also
Resolume, TouchOSC, or a simple script. You configure each recorder
once, and from then on you trigger play, stop, and track changes by
sending OSC messages.

## First-Time Setup

### 1. Prepare the Recorder

Before using TascamBridge, the recorder must be reachable over the
network.

1. Connect the recorder to your network via its Ethernet port.
2. On the recorder, note its IP address (usually shown in the menu
   under network or system settings).
3. Confirm the recorder is set to accept Telnet control (this is
   usually enabled by default).
4. For the SS-R250N: update firmware to V2.17 or later for the most
   reliable connection behaviour.

### 2. Launch TascamBridge

The app opens to a single window with one player card, a shared log
pane below, and an OSC port field at the top.

The app also places an icon in the menu bar. The icon is **red** when
no players are connected and **green** when all configured players are
connected.

### 3. Configure the First Player

Each player card represents one recorder.

1. **Name** — Click the name at the top of the card to rename it
   (e.g. `main`, `backup`, `dialog`). Names must be a single word,
   no spaces, no slashes, and must be unique.
2. **Device** — Choose `SS-R250N` or `HD-R1`.
3. **IP** — Enter the recorder's IP address.
4. **Port** — Leave as `23` unless you've changed the recorder's
   Telnet port.
5. Click **Connect**. The status dot next to the name turns green and
   the shared log shows the connection sequence.

### 4. Add More Players

Click **Add Player** at the top of the window. A new card appears with
its own name, IP, port, and device type. Repeat the configuration
steps above.

Players can be mixed freely — for example, one SS-R250N and one HD-R1
in the same show.

### 5. Set the OSC Port

The field at the top of the window shows the port TascamBridge listens
on, default `5005`. This must match the port your OSC sender is
configured to send to. Changing it takes effect immediately.

## Sending OSC Commands

TascamBridge accepts OSC messages addressed to a specific player,
either by **position** or by **name**.

### Positional addressing

`/player1/...` refers to the first card in the list.
`/player2/...` refers to the second, and so on.

| Command | Effect |
|---|---|
| `/player1/play` | Start playback on the first player |
| `/player2/stop` | Stop playback on the second player |
| `/player3/track` with int argument `42` | Jump to track 42 |

### Named addressing

`/<name>/...` refers to whichever player has that name.

If you rename the first player to `main`, then:

| Command | Effect |
|---|---|
| `/main/play` | Start playback |
| `/main/stop` | Stop playback |
| `/main/track` with int argument `42` | Jump to track 42 |

### Case-insensitivity

Addresses are matched in lowercase. `/MAIN/Play`, `/Main/play`, and
`/main/play` all do the same thing.

### Argument types

The track number can be sent two ways:

- **As a typed argument**: send `/main/track` with an integer argument
  of `42`. This is the recommended form and works directly from QLab.
- **In the address**: send `/main/track/42`. Useful for quick tests or
  senders that can't attach typed arguments.

## Configuring QLab

1. In QLab, create a **Network cue**.
2. Set the **destination** to `127.0.0.1` (or the IP of the machine
   running TascamBridge, if it's on another Mac).
3. Set the **port** to match TascamBridge's OSC port (default `5005`).
4. Set the **message type** to `OSC Message`.
5. Set the **address** to your target, e.g. `/main/play`.
6. For track jumps, add an **integer argument** with the track number.

## The Menu Bar

The menu bar icon shows the aggregate state at a glance:

- **Green** — every configured player is connected.
- **Red** — at least one player is disconnected.

Clicking the icon opens a menu with:

- A connection summary (`2/3 connected`)
- Per-player Play and Stop buttons
- **Show Window** — bring the main window forward
- **Quit**

Per-player buttons are disabled when that player is disconnected.

## The Log Pane

The log shows everything happening in the app: connections,
disconnections, OSC messages received, Telnet commands sent, and any
errors. Entries are prefixed with the player name so you can tell
multiple players apart.

The log is the first place to look if something isn't working as
expected.

## Auto-Reconnect

If a connection drops unexpectedly (network blip, recorder reboot),
TascamBridge will attempt to reconnect automatically, waiting 2 seconds
before the first attempt and doubling the wait each time up to 30
seconds. When the recorder comes back online, the connection
establishes and the retry counter resets.

To intentionally break a connection, use the **Disconnect** button.
That disables auto-reconnect for that player until you click Connect
again.

## Persistence

Your player configuration — names, IPs, ports, device types, expanded
state, and the OSC port — is saved automatically and restored the next
time you launch TascamBridge. Connections are not persisted; every
launch starts disconnected so you can review the setup before going
live.

## Troubleshooting

**The status dot stays red after clicking Connect.**
Check that the IP is correct and the recorder is powered on and on
the same network. The log will show the specific error.

**Commands are sent but the recorder does nothing.**
Verify the device type is set correctly. An SS-R250N will not respond
to HD-R1 commands and vice versa.

**The connection drops after a few minutes of inactivity.**
This shouldn't happen because of the built-in keep-alive, but if it
does, check that the recorder's firmware is up to date. Older firmware
on the SS-R250N had less reliable Telnet handling.

**OSC commands arrive at the app but don't reach a player.**
Check the log for `Unknown player in OSC`. This means the address
referenced a player name that doesn't exist, or a `/playerN` where N
is larger than the number of configured players.

**A player's name won't save.**
Names must be a single word with no spaces or slashes, and must be
unique. The field turns red while typing if the current value is
invalid.

**The app doesn't restore my setup on launch.**
Confirm the app has permission to write to `UserDefaults`. This is
usually automatic; if it fails, the log will show a save error.

## Known Limitations

- **HD-R1 track selection**: The HD-R1 does not support direct
  track-number jumps. Only play, stop, and folder/playlist navigation
  are available for that device.
- **OSC bundles with time tags**: Messages with a future time tag are
  delivered immediately rather than at the specified time. If you need
  scheduled execution, use QLab's own cue timing rather than OSC time
  tags.
- **Raw passthrough**: Any address segment not matching `play`, `stop`,
  or `track` is forwarded verbatim to the recorder as a raw Telnet
  command. This is useful for advanced commands but can produce
  unexpected results if used carelessly.

## Quick Reference

| Task | Action |
|---|---|
| Play on first player | Send `/player1/play` |
| Stop on first player | Send `/player1/stop` |
| Play on player named "main" | Send `/main/play` |
| Jump to track 42 | Send `/main/track` with integer `42` |
| Test without QLab | `echo -n "/player1/play" | nc -u 127.0.0.1 5005` |
| Change OSC port | Edit the field at the top of the window |
| Add a player | Click **Add Player** |
| Remove a player | Click the trash icon on its card |
| Manually connect/disconnect | Buttons on the expanded card |

## License

Copyright (C) 2026 Frederico Pereira

TascamBridge is free software released under the **GNU Affero General
Public License v3.0**. You are welcome to use it, modify it, and share
it, provided derivative works are released under the same license. If
you run a modified version as a network service, you must make the
source available to users of that service.

Full license text: https://www.gnu.org/licenses/agpl-3.0.html

Source code: https://github.com/Xorpereira/TascamBridge
