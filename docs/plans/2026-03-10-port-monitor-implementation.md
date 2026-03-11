# Port Monitor Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a native macOS menu bar app that displays active listening ports and allows killing processes, with a polished native macOS translucent panel UI.

**Architecture:** 
- SwiftUI for the main interface with AppKit integration for status bar behavior
- floating panel for the dropdown panel with NSVisualEffectView for native materials
- lsof command for port detection, kill command for process termination
- MVVM pattern with ObservableObject for state management

**Tech Stack:** Swift 5.9+, SwiftUI, AppKit, Combine

---

## Project Structure

```
PortMonitor/
├── PortMonitor/
│   ├── PortMonitorApp.swift          # App entry point, no dock icon
│   ├── StatusBarController.swift      # NSStatusItem + floating panel management
│   ├── Services/
│   │   ├── PortScanner.swift          # lsof-based port detection
│   │   └── ProcessKiller.swift        # kill command wrapper
│   ├── ViewModels/
│   │   └── PortListViewModel.swift    # ObservableObject for UI state
│   ├── Views/
│   │   ├── PortListView.swift         # Main dropdown content
│   │   ├── PortRowView.swift          # Individual port row with hover
│   │   ├── EmptyStateView.swift       # No ports running state
│   │   └── HeaderView.swift           # App title + quit button
│   └── Models/
│       └── PortInfo.swift             # Port data model
├── PortMonitor/Assets/
│   ├── AppIcon.appiconset/            # App icon assets
│   └── MenuBarIcon.pdf                # Template image for status bar
└── scripts/
    ├── build.sh                       # Build script
    └── create-dmg.sh                  # DMG packaging script
```

---

## Task 1: Create Xcode Project Structure

**Files:**
- Create: `PortMonitor/PortMonitorApp.swift`
- Create: `PortMonitor/Info.plist`
- Create: `PortMonitor.xcodeproj/project.pbxproj`

**Step 1: Create project directory structure**

```bash
mkdir -p PortMonitor/{Services,ViewModels,Views,Models,Assets}
mkdir -p scripts
```

**Step 2: Create PortMonitorApp.swift**

```swift
import SwiftUI

@main
struct PortMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // No main window - menu bar only
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)
        
        // Initialize status bar
        statusBarController = StatusBarController()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup
    }
}
```

**Step 3: Create Info.plist**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>LSUIElement</key>
    <true/>
    <key>CFBundleName</key>
    <string>Port Monitor</string>
    <key>CFBundleDisplayName</key>
    <string>Port Monitor</string>
    <key>CFBundleIdentifier</key>
    <string>com.portmonitor.app</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
</dict>
</plist>
```

**Step 4: Commit**

```bash
git add PortMonitor/
git commit -m "feat: create Xcode project structure"
```

---

## Task 2: Implement PortInfo Model

**Files:**
- Create: `PortMonitor/Models/PortInfo.swift`

**Step 1: Write the model**

```swift
import Foundation

struct PortInfo: Identifiable, Equatable, Comparable {
    let id = UUID()
    let port: Int
    let processName: String
    let pid: Int
    let protocol: String
    
    static func < (lhs: PortInfo, rhs: PortInfo) -> Bool {
        lhs.port < rhs.port
    }
}
```

**Step 2: Commit**

```bash
git add PortMonitor/Models/PortInfo.swift
git commit -m "feat: add PortInfo model"
```

---

## Task 3: Implement PortScanner Service

**Files:**
- Create: `PortMonitor/Services/PortScanner.swift`

**Step 1: Write the service**

```swift
import Foundation
import Combine

class PortScanner: ObservableObject {
    @Published var ports: [PortInfo] = []
    
    private var timer: Timer?
    private let updateInterval: TimeInterval = 3.0
    
    func startScanning() {
        scan() // Initial scan
        timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { _ in
            self.scan()
        }
    }
    
    func stopScanning() {
        timer?.invalidate()
        timer = nil
    }
    
    private func scan() {
        let task = Process()
        task.launchPath = "/usr/sbin/lsof"
        task.arguments = ["-iTCP", "-sTCP:LISTEN", "-P", "-n"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            task.waitUntilExit()
            
            let parsed = parseLsofOutput(output)
            DispatchQueue.main.async {
                self.ports = parsed.sorted()
            }
        } catch {
            print("Failed to scan ports: \(error)")
        }
    }
    
    private func parseLsofOutput(_ output: String) -> [PortInfo] {
        var results: [PortInfo] = []
        let lines = output.split(separator: "\n")
        
        // Skip header line
        for line in lines.dropFirst() {
            let components = line.split(separator: " ", omittingEmptySubsequences: true)
            guard components.count >= 9 else { continue }
            
            let processName = String(components[0])
            guard let pid = Int(components[1]) else { continue }
            
            // Parse port from NAME column (e.g., "*:3000" or "127.0.0.1:3000")
            let nameField = String(components[8])
            guard let port = extractPort(from: nameField) else { continue }
            
            let protocolType = components.count > 7 ? String(components[7]) : "TCP"
            
            // Filter out system processes and common system ports
            if !isSystemPort(port) && !isSystemProcess(processName) {
                results.append(PortInfo(
                    port: port,
                    processName: processName,
                    pid: pid,
                    protocol: protocolType
                ))
            }
        }
        
        return results
    }
    
    private func extractPort(from address: String) -> Int? {
        // Handle formats like "*:3000", "127.0.0.1:3000", "[::]:3000"
        if let colonIndex = address.lastIndex(of: ":") {
            let portString = String(address.suffix(from: address.index(after: colonIndex)))
            return Int(portString)
        }
        return nil
    }
    
    private func isSystemPort(_ port: Int) -> Bool {
        // Common system ports to exclude
        let systemPorts = [22, 53, 88, 445, 548, 631, 1024]
        return systemPorts.contains(port)
    }
    
    private func isSystemProcess(_ name: String) -> Bool {
        // System processes to exclude
        let systemProcesses = ["launchd", "kernel", "apsd", "cloudd"]
        return systemProcesses.contains(name.lowercased())
    }
}
```

**Step 2: Commit**

```bash
git add PortMonitor/Services/PortScanner.swift
git commit -m "feat: add PortScanner service with lsof integration"
```

---

## Task 4: Implement ProcessKiller Service

**Files:**
- Create: `PortMonitor/Services/ProcessKiller.swift`

**Step 1: Write the service**

```swift
import Foundation

enum KillError: Error {
    case processNotFound
    case permissionDenied
    case killFailed(String)
}

class ProcessKiller {
    static func kill(pid: Int) async throws {
        let task = Process()
        task.launchPath = "/bin/kill"
        task.arguments = ["-9", String(pid)]
        
        let pipe = Pipe()
        task.standardError = pipe
        
        return try await withCheckedThrowingContinuation { continuation in
            task.terminationHandler = { process in
                if process.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
                    let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                    continuation.resume(throwing: KillError.killFailed(errorMessage))
                }
            }
            
            do {
                try task.run()
            } catch {
                continuation.resume(throwing: KillError.killFailed(error.localizedDescription))
            }
        }
    }
    
    static func kill(port: PortInfo) async throws {
        try await kill(pid: port.pid)
    }
}
```

**Step 2: Commit**

```bash
git add PortMonitor/Services/ProcessKiller.swift
git commit -m "feat: add ProcessKiller service"
```

---

## Task 5: Implement PortListViewModel

**Files:**
- Create: `PortMonitor/ViewModels/PortListViewModel.swift`

**Step 1: Write the view model**

```swift
import Foundation
import Combine

@MainActor
class PortListViewModel: ObservableObject {
    @Published var ports: [PortInfo] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var killingPortId: UUID?
    
    private let scanner = PortScanner()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        scanner.$ports
            .receive(on: DispatchQueue.main)
            .assign(to: &$ports)
    }
    
    func startScanning() {
        scanner.startScanning()
    }
    
    func stopScanning() {
        scanner.stopScanning()
    }
    
    func killPort(_ port: PortInfo) async {
        guard killingPortId == nil else { return }
        
        killingPortId = port.id
        errorMessage = nil
        
        do {
            try await ProcessKiller.kill(port: port)
            // Port will be removed automatically on next scan
        } catch KillError.processNotFound {
            errorMessage = "Process already terminated"
        } catch KillError.permissionDenied {
            errorMessage = "Permission denied"
        } catch {
            errorMessage = "Failed to kill process"
        }
        
        killingPortId = nil
    }
    
    func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
```

**Step 2: Commit**

```bash
git add PortMonitor/ViewModels/PortListViewModel.swift
git commit -m "feat: add PortListViewModel"
```

---

## Task 6: Implement SwiftUI Views

**Files:**
- Create: `PortMonitor/Views/HeaderView.swift`
- Create: `PortMonitor/Views/PortRowView.swift`
- Create: `PortMonitor/Views/EmptyStateView.swift`
- Create: `PortMonitor/Views/PortListView.swift`

**Step 1: HeaderView.swift**

```swift
import SwiftUI

struct HeaderView: View {
    let onQuit: () -> Void
    
    var body: some View {
        HStack {
            Text("Port Monitor")
                .font(.system(size: 14, weight: .semibold))
            
            Spacer()
            
            Button(action: onQuit) {
                Image(systemName: "power")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.red)
                    .frame(width: 28, height: 28)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
```

**Step 2: PortRowView.swift**

```swift
import SwiftUI

struct PortRowView: View {
    let port: PortInfo
    let isKilling: Bool
    let onKill: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(Color.blue)
                .frame(width: 6, height: 6)
            
            // Port number
            Text("\(port.port)")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(.blue)
            
            // Process name
            Text(port.processName)
                .font(.system(size: 13))
                .foregroundColor(.primary)
                .lineLimit(1)
            
            Spacer()
            
            // Kill button (visible on hover)
            if isHovered && !isKilling {
                Button(action: onKill) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.red)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(PlainButtonStyle())
                .transition(.opacity)
            }
            
            if isKilling {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 20, height: 20)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 36)
        .background(isHovered ? Color(NSColor.selectedContentBackgroundColor).opacity(0.3) : Color.clear)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}
```

**Step 3: EmptyStateView.swift**

```swift
import SwiftUI

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "network")
                .font(.system(size: 24))
                .foregroundColor(.secondary)
            
            Text("No development ports running")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .padding(.vertical, 24)
    }
}
```

**Step 4: PortListView.swift**

```swift
import SwiftUI

struct PortListView: View {
    @StateObject private var viewModel = PortListViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HeaderView(onQuit: viewModel.quitApp)
            
            // Divider
            Divider()
            
            // Port list or empty state
            if viewModel.ports.isEmpty {
                EmptyStateView()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.ports) { port in
                            PortRowView(
                                port: port,
                                isKilling: viewModel.killingPortId == port.id,
                                onKill: {
                                    Task {
                                        await viewModel.killPort(port)
                                    }
                                }
                            )
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
        }
        .frame(width: 280)
        .onAppear {
            viewModel.startScanning()
        }
        .onDisappear {
            viewModel.stopScanning()
        }
    }
}
```

**Step 5: Commit**

```bash
git add PortMonitor/Views/
git commit -m "feat: add SwiftUI views for port list"
```

---

## Task 7: Implement StatusBarController

**Files:**
- Create: `PortMonitor/StatusBarController.swift`

**Step 1: Write the controller**

```swift
import SwiftUI
import AppKit

class StatusBarController: NSObject, floating panelDelegate {
    private var statusItem: NSStatusItem?
    private var popover: floating panel?
    private var eventMonitor: EventMonitor?
    
    override init() {
        super.init()
        setupStatusItem()
        setupPopover()
        setupEventMonitor()
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "network", accessibilityDescription: "Port Monitor")
            button.image?.size = NSSize(width: 18, height: 18)
            button.image?.isTemplate = true
            button.action = #selector(togglePopover)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }
    
    private func setupPopover() {
        let popover = floating panel()
        popover.contentSize = NSSize(width: 280, height: 400)
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        
        // Use visual effect view for native macOS material
        let contentView = PortListView()
        popover.contentViewController = NSHostingController(rootView: contentView)
        
        // Apply material background
        if let visualEffectView = popover.contentViewController?.view.superview?.superview {
            visualEffectView.wantsLayer = true
            if let layer = visualEffectView.layer {
                layer.backgroundColor = NSColor.clear.cgColor
            }
        }
        
        self.popover = popover
    }
    
    private func setupEventMonitor() {
        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, let popover = self.popover else { return }
            if popover.isShown {
                self.closePopover()
            }
        }
    }
    
    @objc private func togglePopover() {
        guard let popover = popover, let button = statusItem?.button else { return }
        
        if popover.isShown {
            closePopover()
        } else {
            showPopover(from: button)
        }
    }
    
    private func showPopover(from button: NSStatusBarButton) {
        popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        eventMonitor?.start()
    }
    
    private func closePopover() {
        popover?.close()
        eventMonitor?.stop()
    }
    
    // MARK: - floating panelDelegate
    
    func popoverDidClose(_ notification: Notification) {
        eventMonitor?.stop()
    }
}

// MARK: - Event Monitor

class EventMonitor {
    private var monitor: Any?
    private let mask: NSEvent.EventTypeMask
    private let handler: (NSEvent?) -> Void
    
    init(mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent?) -> Void) {
        self.mask = mask
        self.handler = handler
    }
    
    deinit {
        stop()
    }
    
    func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler)
    }
    
    func stop() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}
```

**Step 2: Commit**

```bash
git add PortMonitor/StatusBarController.swift
git commit -m "feat: add StatusBarController with floating panel"
```

---

## Task 8: Create App Icons

**Files:**
- Create: `PortMonitor/Assets/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Create: `PortMonitor/Assets/Assets.xcassets/MenuBarIcon.imageset/Contents.json`

**Step 1: Create icon assets structure**

```bash
mkdir -p PortMonitor/Assets/Assets.xcassets/AppIcon.appiconset
mkdir -p PortMonitor/Assets/Assets.xcassets/MenuBarIcon.imageset
```

**Step 2: Create Contents.json for AppIcon**

```json
{
  "images" : [
    {
      "filename" : "icon_16x16.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "16x16"
    },
    {
      "filename" : "icon_16x16@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "16x16"
    },
    {
      "filename" : "icon_32x32.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "32x32"
    },
    {
      "filename" : "icon_32x32@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "32x32"
    },
    {
      "filename" : "icon_128x128.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "128x128"
    },
    {
      "filename" : "icon_128x128@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "128x128"
    },
    {
      "filename" : "icon_256x256.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "256x256"
    },
    {
      "filename" : "icon_256x256@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "256x256"
    },
    {
      "filename" : "icon_512x512.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "512x512"
    },
    {
      "filename" : "icon_512x512@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "512x512"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

**Step 3: Create simple icon generation script**

```bash
# scripts/generate-icons.sh
#!/bin/bash

# Create a simple SF Symbol-based icon using Swift
swift << 'SWIFT_EOF'
import Cocoa

let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size, flipped: false) { rect in
    // White background
    NSColor.white.setFill()
    rect.fill()
    
    // Draw network symbol
    let config = NSImage.SymbolConfiguration(pointSize: 512, weight: .regular)
    if let symbol = NSImage(systemSymbolName: "network", accessibilityDescription: nil)?.withSymbolConfiguration(config) {
        let symbolRect = NSRect(
            x: (rect.width - symbol.size.width) / 2,
            y: (rect.height - symbol.size.height) / 2,
            width: symbol.size.width,
            height: symbol.size.height
        )
        symbol.draw(in: symbolRect)
    }
    
    return true
}

// Save as PNG
if let tiffData = image.tiffRepresentation,
   let bitmap = NSBitmapImageRep(data: tiffData),
   let pngData = bitmap.representation(using: .png, properties: [:]) {
    try? pngData.write(to: URL(fileURLWithPath: "icon_1024x1024.png"))
    print("Generated icon_1024x1024.png")
}
SWIFT_EOF
```

**Step 4: Commit**

```bash
git add PortMonitor/Assets/
git commit -m "feat: add app icon assets structure"
```

---

## Task 9: Create Build Scripts

**Files:**
- Create: `scripts/build.sh`
- Create: `scripts/create-dmg.sh`

**Step 1: build.sh**

```bash
#!/bin/bash
set -e

PROJECT_NAME="PortMonitor"
BUILD_DIR="build"
DERIVED_DATA_PATH="$BUILD_DIR/DerivedData"
ARCHIVE_PATH="$BUILD_DIR/$PROJECT_NAME.xcarchive"
APP_PATH="$BUILD_DIR/$PROJECT_NAME.app"

# Clean previous builds
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "Building $PROJECT_NAME..."

# Build archive
xcodebuild archive \
    -project "$PROJECT_NAME.xcodeproj" \
    -scheme "$PROJECT_NAME" \
    -destination "generic/platform=macOS" \
    -archivePath "$ARCHIVE_PATH" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO

# Export app
cp -R "$ARCHIVE_PATH/Products/Applications/$PROJECT_NAME.app" "$APP_PATH"

echo "Build complete: $APP_PATH"
```

**Step 2: create-dmg.sh**

```bash
#!/bin/bash
set -e

PROJECT_NAME="PortMonitor"
BUILD_DIR="build"
APP_PATH="$BUILD_DIR/$PROJECT_NAME.app"
DMG_NAME="$PROJECT_NAME.dmg"
VOLUME_NAME="Port Monitor"

if [ ! -d "$APP_PATH" ]; then
    echo "Error: $APP_PATH not found. Run build.sh first."
    exit 1
fi

echo "Creating DMG..."

# Create temporary directory
TMP_DIR=$(mktemp -d)
MOUNT_DIR="$TMP_DIR/mount"

# Create DMG
du -sh "$APP_PATH" | awk '{print $1}'
hdiutil create -size 50m -fs HFS+ -volname "$VOLUME_NAME" "$TMP_DIR/temp.dmg"

# Mount DMG
hdiutil attach "$TMP_DIR/temp.dmg" -mountpoint "$MOUNT_DIR"

# Copy app
cp -R "$APP_PATH" "$MOUNT_DIR/"

# Create Applications symlink
ln -s /Applications "$MOUNT_DIR/Applications"

# Set window properties (optional, requires applescript)
osascript << EOF
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {400, 100, 900, 400}
        set viewOptions to icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 128
        set position of item "$PROJECT_NAME.app" of container window to {150, 150}
        set position of item "Applications" of container window to {350, 150}
        close
    end tell
end tell
EOF

# Unmount
hdiutil detach "$MOUNT_DIR"

# Convert to compressed DMG
hdiutil convert "$TMP_DIR/temp.dmg" -format UDZO -o "$BUILD_DIR/$DMG_NAME"

# Cleanup
rm -rf "$TMP_DIR"

echo "DMG created: $BUILD_DIR/$DMG_NAME"
```

**Step 3: Commit**

```bash
git add scripts/
git commit -m "feat: add build and packaging scripts"
```

---

## Task 10: Create Project File

**Files:**
- Create: `PortMonitor.xcodeproj/project.pbxproj`

**Note:** This is a simplified representation. In practice, use Xcode or xcodegen to create the project file.

**Alternative: Create project.yml for xcodegen**

```yaml
name: PortMonitor
targets:
  PortMonitor:
    type: application
    platform: macOS
    deploymentTarget: "13.0"
    sources:
      - PortMonitor
    settings:
      INFOPLIST_FILE: PortMonitor/Info.plist
      PRODUCT_BUNDLE_IDENTIFIER: com.portmonitor.app
      PRODUCT_NAME: Port Monitor
      GENERATE_INFOPLIST_FILE: YES
      CODE_SIGN_IDENTITY: "-"
      CODE_SIGNING_REQUIRED: NO
      CODE_SIGNING_ALLOWED: NO
```

**Step 1: Commit**

```bash
git add project.yml
git commit -m "feat: add xcodegen project configuration"
```

---

## Task 11: Create README

**Files:**
- Create: `README.md`

**Step 1: Write README**

```markdown
# Port Monitor

A minimal macOS menu bar app for monitoring and managing listening ports.

## Features

- Lives in the menu bar, no dock icon
- Shows active listening TCP ports
- Displays process names
- Kill processes with hover-reveal button
- Native macOS translucent panel
- Auto-refreshes every 3 seconds

## Requirements

- macOS 13.0+
- Xcode 15.0+

## Building

### Using xcodegen (recommended)

```bash
# Install xcodegen if needed
brew install xcodegen

# Generate project
xcodegen generate

# Build
./scripts/build.sh
```

### Using Xcode

1. Open `PortMonitor.xcodeproj`
2. Select Product > Build

## Packaging

```bash
./scripts/create-dmg.sh
```

## Usage

1. Launch Port Monitor
2. Click the menu bar icon (network symbol)
3. View active ports
4. Hover over a port to reveal the Kill button
5. Click the power button to quit

## Architecture

- **SwiftUI**: Main UI
- **AppKit**: Status bar integration (NSStatusItem, floating panel)
- **lsof**: Port detection
- **kill**: Process termination
```

**Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add README with build instructions"
```

---

## Verification Checklist

Before claiming completion, verify:

1. **Menu bar icon**: Appears in status bar
2. **Panel placement**: Opens directly beneath the icon
3. **Visual appearance**: Native translucent material
4. **Port display**: Shows port number and process name
5. **Hover behavior**: Kill button appears on hover
6. **Kill functionality**: Actually terminates the process
7. **Quit behavior**: Fully exits the app
8. **Empty state**: Shows when no ports active
9. **App icon**: Appears in Applications folder
10. **DMG creation**: Builds successfully

## Implementation Notes

1. **No Dock Icon**: Uses `LSUIElement` in Info.plist and `setActivationPolicy(.accessory)`
2. **Native Materials**: Uses floating panel with system visual effect
3. **Port Detection**: Uses `lsof -iTCP -sTCP:LISTEN -P -n` for accurate results
4. **Process Killing**: Uses `kill -9` for reliable termination
5. **Auto-refresh**: 3-second timer with Combine publishers
6. **Hover Effect**: SwiftUI onHover with animation
7. **Click-outside-close**: EventMonitor for global mouse events
