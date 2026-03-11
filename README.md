# Port Monitor

A minimal macOS menu bar app for monitoring and managing listening ports.

## Features

- Lives in the menu bar, no dock icon
- Shows active listening TCP ports
- Displays process names
- Kill processes from compact utility rows
- Native macOS Liquid Glass popover styling
- Auto-refreshes every 3 seconds

## Requirements

- macOS 26.0+
- Xcode 26.0+ (for building)
- xcodegen (optional, for project generation)

## Building

### Prerequisites

- macOS with Apple Command Line Tools installed
- `iconutil` available (ships with macOS)

### Build Steps

```bash
# Run the automated tests
swift test -j 2

# Build the release app bundle
./scripts/build.sh
```

This produces:

- `build/PortMonitor.app`

The build uses Swift Package Manager for compilation and then assembles a native macOS `.app` bundle with the included menu bar asset and generated `.icns` app icon.

## Packaging

```bash
# Create DMG installer
./scripts/create-dmg.sh
```

This produces:

- `build/PortMonitor.dmg`

## Usage

1. Launch Port Monitor
2. Click the Port Monitor icon in the menu bar
3. View active ports
4. Click **Kill** next to any listening port you want to terminate
5. Click the power button to quit

## Architecture

- **SwiftUI**: Popover UI and menu content
- **AppKit**: Status bar integration (`NSStatusItem`, floating `NSPanel`)
- **lsof**: Port discovery via machine-readable command output
- **kill**: Process termination with graceful fallback from `TERM` to `KILL`
- **Swift Testing**: Deterministic parser, killer, and view-model tests

## Project Structure

```
PortMonitor/
├── PortMonitor/
│   ├── PortMonitorApp.swift           # App entry point
│   ├── StatusBarController.swift      # NSStatusItem + floating panel
│   ├── Services/
│   │   ├── PortScanner.swift          # lsof-based port detection
│   │   └── ProcessKiller.swift        # kill command wrapper
│   ├── ViewModels/
│   │   └── PortListViewModel.swift    # ObservableObject for UI state
│   ├── Views/
│   │   ├── PortListView.swift         # Main dropdown content
│   │   ├── PortRowView.swift          # Individual port row
│   │   ├── EmptyStateView.swift       # No ports running state
│   │   └── HeaderView.swift           # App title + quit button
│   ├── Models/
│   │   └── PortInfo.swift             # Port data model
│   └── Assets/
│       └── Assets.xcassets/           # App icons
├── scripts/
│   ├── build.sh                       # Build script
│   └── create-dmg.sh                  # DMG packaging
└── project.yml                        # xcodegen configuration
```

## Implementation Notes

1. **No Dock Icon**: Uses `LSUIElement` and `setActivationPolicy(.accessory)`
2. **Native Liquid Glass UI**: Uses an arrowless floating panel with SwiftUI Liquid Glass surfaces and controls
3. **Port Detection**: Uses `lsof -nP -iTCP -sTCP:LISTEN -FpcnT` for stable parsing
4. **Process Killing**: Attempts `TERM` first and falls back to `KILL` when appropriate
5. **Auto-refresh**: 3-second timer with explicit refresh on successful kill actions
6. **States Covered**: Loading, empty, populated, and error states are all rendered in the popover
7. **Canonical Verification Command**: `swift test -j 2`

## License

MIT
