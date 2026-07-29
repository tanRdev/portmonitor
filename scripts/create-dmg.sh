#!/bin/bash
set -euo pipefail

PROJECT_NAME="PortMonitor"
BUILD_DIR="build"
APP_PATH="$BUILD_DIR/$PROJECT_NAME.app"
DMG_NAME="$PROJECT_NAME.dmg"
VOLUME_NAME="Port Monitor"

if [ ! -d "$APP_PATH" ]; then
    echo "Error: $APP_PATH not found. Run ./scripts/build.sh first."
    exit 1
fi

echo "Creating DMG..."

# Create temporary directory
TMP_DIR=$(mktemp -d)
MOUNT_DIR="$TMP_DIR/mount"

# Create DMG with estimated size
APP_SIZE=$(du -sm "$APP_PATH" | awk '{print $1}')
DMG_SIZE=$((APP_SIZE + 20))

hdiutil create -size ${DMG_SIZE}m -fs HFS+ -volname "$VOLUME_NAME" "$TMP_DIR/temp.dmg"

# Mount DMG
hdiutil attach "$TMP_DIR/temp.dmg" -mountpoint "$MOUNT_DIR"

# Copy app
cp -R "$APP_PATH" "$MOUNT_DIR/"

# Create Applications symlink
ln -s /Applications "$MOUNT_DIR/Applications"

# Copy DMG background artwork if present
mkdir -p "$MOUNT_DIR/.background"
if [ -f "assets/app-icon-source.png" ]; then
    cp "assets/app-icon-source.png" "$MOUNT_DIR/.background/background.png"
fi

# Set window properties using AppleScript (best effort)
osascript << EOF 2>/dev/null || true
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
        if exists file ".background:background.png" then
            set background picture of viewOptions to file ".background:background.png"
        end if
        set position of item "$PROJECT_NAME.app" of container window to {150, 150}
        set position of item "Applications" of container window to {350, 150}
        close
    end tell
end tell
EOF

# Unmount
hdiutil detach "$MOUNT_DIR" || true

# Convert to compressed DMG
rm -f "$BUILD_DIR/$DMG_NAME"
hdiutil convert "$TMP_DIR/temp.dmg" -format UDZO -o "$BUILD_DIR/$DMG_NAME"

# Cleanup
rm -rf "$TMP_DIR"

echo "DMG created: $BUILD_DIR/$DMG_NAME"
