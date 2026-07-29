#!/bin/bash
set -e

cd "$(dirname "$0")/.."

APP_NAME="PortMonitor"
BUILD_DIR="build"
SPM_BUILD=".build/release"

echo "Building $APP_NAME..."

# Build release
swift build -c release

# Create app bundle
echo "Creating app bundle..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/$APP_NAME.app/Contents/MacOS"
mkdir -p "$BUILD_DIR/$APP_NAME.app/Contents/Resources"

# Copy binary
cp "$SPM_BUILD/$APP_NAME" "$BUILD_DIR/$APP_NAME.app/Contents/MacOS/"

# Copy resource bundle when SwiftPM emits one.
if [ -d "$SPM_BUILD/PortMonitor_PortMonitor.resources" ]; then
    cp -R "$SPM_BUILD/PortMonitor_PortMonitor.resources" "$BUILD_DIR/$APP_NAME.app/Contents/Resources/"
    cp "$SPM_BUILD/PortMonitor_PortMonitor.resources/MenuBarIcon.png" "$BUILD_DIR/$APP_NAME.app/Contents/Resources/" 2>/dev/null || true
fi

# The executable target excludes its asset catalog, so install the menu-bar
# template image directly into the application bundle.
if [ -f "PortMonitor/Assets/MenuBarIcon.png" ]; then
    cp "PortMonitor/Assets/MenuBarIcon.png" "$BUILD_DIR/$APP_NAME.app/Contents/Resources/MenuBarIcon.png"
fi

# Create Info.plist
cat > "$BUILD_DIR/$APP_NAME.app/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>PortMonitor</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>us.hanagata.portmonitor</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Port Monitor</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.1.0</string>
    <key>CFBundleVersion</key>
    <string>4</string>
    <key>LSMinimumSystemVersion</key>
    <string>26.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# Create entitlements file for ad-hoc signing
ENTITLEMENTS_PATH="$BUILD_DIR/entitlements.plist"
cat > "$ENTITLEMENTS_PATH" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.get-task-allow</key>
    <true/>
</dict>
</plist>
EOF

# Convert app icon (PNG -> icns)
ICONSET_DIR="$BUILD_DIR/AppIcon.iconset"
mkdir -p "$ICONSET_DIR"

SOURCE_ICON="assets/app-icon-source.png"
if [ -f "$SOURCE_ICON" ]; then
    echo "Generating app icon..."

    # iconutil requires exact dimensions
    sips -z 16 16     "$SOURCE_ICON" --out "$ICONSET_DIR/icon_16x16.png" > /dev/null
    sips -z 32 32     "$SOURCE_ICON" --out "$ICONSET_DIR/icon_16x16@2x.png" > /dev/null
    sips -z 32 32     "$SOURCE_ICON" --out "$ICONSET_DIR/icon_32x32.png" > /dev/null
    sips -z 64 64     "$SOURCE_ICON" --out "$ICONSET_DIR/icon_32x32@2x.png" > /dev/null
    sips -z 128 128   "$SOURCE_ICON" --out "$ICONSET_DIR/icon_128x128.png" > /dev/null
    sips -z 256 256   "$SOURCE_ICON" --out "$ICONSET_DIR/icon_128x128@2x.png" > /dev/null
    sips -z 256 256   "$SOURCE_ICON" --out "$ICONSET_DIR/icon_256x256.png" > /dev/null
    sips -z 512 512   "$SOURCE_ICON" --out "$ICONSET_DIR/icon_256x256@2x.png" > /dev/null
    sips -z 512 512   "$SOURCE_ICON" --out "$ICONSET_DIR/icon_512x512.png" > /dev/null
    sips -z 1024 1024 "$SOURCE_ICON" --out "$ICONSET_DIR/icon_512x512@2x.png" > /dev/null

    if iconutil -c icns "$ICONSET_DIR" -o "$BUILD_DIR/$APP_NAME.app/Contents/Resources/AppIcon.icns"; then
        echo "  AppIcon.icns generated from $SOURCE_ICON"
    else
        echo "  iconutil failed; falling back to plain PNG"
        cp "$SOURCE_ICON" "$BUILD_DIR/$APP_NAME.app/Contents/Resources/AppIcon.icns"
    fi

    rm -rf "$ICONSET_DIR"
elif [ -f "assets/AppIcon.icns" ]; then
    cp "assets/AppIcon.icns" "$BUILD_DIR/$APP_NAME.app/Contents/Resources/"
    echo "  AppIcon.icns: installed"
fi

# Code sign (ad-hoc for local builds)
# Must run AFTER all bundle contents are final — any file written into the
# bundle after signing breaks the seal and launchd will kill the app on open.
codesign --force --sign - \
    --entitlements "$ENTITLEMENTS_PATH" \
    "$BUILD_DIR/$APP_NAME.app/Contents/MacOS/$APP_NAME" 2>/dev/null || true

codesign --force --sign - "$BUILD_DIR/$APP_NAME.app" 2>/dev/null || true

echo ""
echo "✅ Built: $BUILD_DIR/$APP_NAME.app"
echo ""
echo "To install:"
echo "  cp -R $BUILD_DIR/$APP_NAME.app /Applications/"
