<div align="center">

  <img src="./assets/icons/port-grid/port-grid-readme.svg" alt="Port Monitor logo" width="96" />

  # Port Monitor

  A small macOS menu bar app that shows which local ports are listening, which process owns them, and lets you kill that process without leaving the menu bar.

  [Download](#download) · [What it does](#what-it-does) · [Build from source](#build-from-source) · [Usage](#usage)

</div>

## Why port monitor

Port Monitor is for the familiar "what is using this port?" moment. Click the menu bar icon, see the current TCP listeners, and stop the one you do not need anymore.

## What it does

- Shows active listening TCP ports
- Lists the process name and PID for each port
- Lets you kill a process right from the menu
- Runs as a menu-bar-only app, so it stays out of the Dock
- Ships as a universal build for Apple Silicon and Intel Macs

## Download

1. Open the [latest release](https://github.com/tanRdev/portmonitor/releases/latest).
2. Download `PortMonitor.dmg` from the release assets.
3. Open the DMG and drag **Port Monitor** into **Applications**.
4. Launch the app from Applications.

> [!NOTE]
> Port Monitor currently targets macOS 26 or later.

> [!IMPORTANT]
> Release builds are convenience builds for now. The app is not signed or notarized yet, so macOS Gatekeeper may warn on first launch. If that happens, open the app from Finder with **Open**, or build it locally.

## Build from source

### Requirements

- macOS 26+
- Xcode 26 or Apple developer tools with Swift 6.2+
- `iconutil` (included with macOS)

### Build commands

```bash
# Run tests
swift test --build-path /tmp/portmonitor-spm --disable-experimental-prebuilts -j 2

# Build the app bundle
./scripts/build.sh

# Package a DMG
./scripts/create-dmg.sh
```

Artifacts end up in `build/`:

- `build/PortMonitor.app`
- `build/PortMonitor.dmg`

## How it works

Port Monitor uses `lsof -nP -iTCP -sTCP:LISTEN -FpcnT` to find local listening TCP ports. It parses that output, turns it into app models, and shows the results in a menu bar UI. From there you can refresh the list, see which process owns a port, and kill it when you need to free something up.

## Usage

1. Launch Port Monitor.
2. Click the menu bar icon.
3. Review the current listening ports.
4. Click **Kill** next to a process you want to stop.
5. Use the power button to quit the app.

## Project layout

```
PortMonitor/
├── PortMonitor/              # App entry point, UI, services, models
├── Tests/PortMonitorTests/   # Parsing, command runner, view model tests
├── scripts/                  # Build, packaging, and icon tooling
├── assets/icons/             # Source artwork and exported icons
├── Package.swift             # Swift Package Manager setup
└── project.yml               # XcodeGen project definition
```

## Development notes

- The app is a menu-bar-only macOS app via `LSUIElement`.
- Release automation builds and publishes a DMG from GitHub Actions.
- The packaged app is built as a universal binary for Apple Silicon and Intel Macs.
