<div align="center">

  <img src="./assets/icons/port-grid/port-grid-readme.svg" alt="Port Monitor logo" width="96" />

  # Port Monitor

  A small macOS menu bar app that shows listening ports, the processes behind them, and lets you stop them without leaving the menu bar.

  [Installation](#installation) • [Releases](#releases) • [Build from source](#build-from-source) • [Usage](#usage)

</div>

## Overview

Port Monitor sits in the macOS menu bar and keeps a live view of local listening TCP ports. It is built for quick checks: open the menu, see what is bound, and stop a process when you need to free a port.

## Features

- Menu bar only, with no dock icon
- Lists active listening TCP ports and process names
- Lets you stop a process directly from the menu
- Refreshes automatically every 3 seconds
- Uses native SwiftUI and AppKit macOS UI
- Covers loading, empty, populated, and error states

## Installation

### Download the app

1. Open the [latest release](https://github.com/tanRdev/portmonitor/releases/latest).
2. Download `PortMonitor.dmg` from the release assets.
3. Open the DMG and drag **Port Monitor** into **Applications**.
4. Launch the app from Applications.

> [!NOTE]
> The app targets macOS 26 or later.

> [!IMPORTANT]
> Release automation currently publishes convenience builds. If Gatekeeper warns on first launch, open the app from Finder with **Open** or build locally until signing and notarization are added.

## Releases

Release builds include a DMG installer so you can install Port Monitor without building it yourself.

- Browse all releases: [github.com/tanRdev/portmonitor/releases](https://github.com/tanRdev/portmonitor/releases)
- Latest DMG: [github.com/tanRdev/portmonitor/releases/latest](https://github.com/tanRdev/portmonitor/releases/latest)

## Build from source

### Requirements

- macOS 26+
- Xcode 26 or current Apple developer tools that include Swift 6.2+
- `iconutil` (included with macOS)

### Build steps

```bash
# Run tests
swift test --build-path /tmp/portmonitor-spm --disable-experimental-prebuilts -j 2

# Build the app bundle
./scripts/build.sh

# Create the DMG installer
./scripts/create-dmg.sh
```

Artifacts are written to `build/`:

- `build/PortMonitor.app`
- `build/PortMonitor.dmg`

## Usage

1. Launch Port Monitor.
2. Click the menu bar icon.
3. Review the list of listening ports.
4. Click **Kill** next to a process you want to stop.
5. Use the power button to quit the app.

## Architecture

- **SwiftUI** for the popover interface
- **AppKit** for the status item and floating panel
- **lsof** for machine-readable port discovery
- **kill** for process termination with `TERM` then `KILL` fallback
- **Swift Testing** for parser, command-runner, layout, and view-model coverage

## Project structure

```text
PortMonitor/
├── PortMonitor/
│   ├── PortMonitorApp.swift
│   ├── StatusBarController.swift
│   ├── Models/
│   ├── Services/
│   ├── Support/
│   ├── ViewModels/
│   ├── Views/
│   └── Assets/
├── Tests/PortMonitorTests/
├── scripts/
└── assets/icons/
```

## Notes

- Port discovery uses `lsof -nP -iTCP -sTCP:LISTEN -FpcnT`.
- The app uses `LSUIElement` so it stays out of the dock.
- Release packaging builds separate Apple Silicon and Intel binaries, then merges them into one universal app executable.
