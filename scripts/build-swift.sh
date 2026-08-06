#!/bin/bash
set -e

cd "$(dirname "$0")/.."

APP_NAME="PortMonitor"
BUILD_DIR="build"
ARM64_BUILD=".build/arm64-apple-macosx/release"
X86_64_BUILD=".build/x86_64-apple-macosx/release"

echo "Building $APP_NAME (universal: arm64 + x86_64)..."

# Build release for both architectures. Multi-arch `swift build` needs
# XCBuild, which is not available in every toolchain, so build per-arch and
# combine with lipo instead.
swift build -c release --arch arm64
swift build -c release --arch x86_64

# Create app bundle
echo "Creating app bundle..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/$APP_NAME.app/Contents/MacOS"
mkdir -p "$BUILD_DIR/$APP_NAME.app/Contents/Resources"

# Combine the per-arch binaries into a single universal binary
lipo -create "$ARM64_BUILD/$APP_NAME" "$X86_64_BUILD/$APP_NAME" \
    -output "$BUILD_DIR/$APP_NAME.app/Contents/MacOS/$APP_NAME"

# Copy resource bundle when SwiftPM emits one (resources are arch-independent).
if [ -d "$ARM64_BUILD/PortMonitor_PortMonitor.resources" ]; then
    cp -R "$ARM64_BUILD/PortMonitor_PortMonitor.resources" "$BUILD_DIR/$APP_NAME.app/Contents/Resources/"
    cp "$ARM64_BUILD/PortMonitor_PortMonitor.resources/MenuBarIcon.png" "$BUILD_DIR/$APP_NAME.app/Contents/Resources/" 2>/dev/null || true
fi

# The executable target excludes its asset catalog, so install the menu-bar
# template image directly into the application bundle.
if [ -f "PortMonitor/Assets/MenuBarIcon.png" ]; then
    cp "PortMonitor/Assets/MenuBarIcon.png" "$BUILD_DIR/$APP_NAME.app/Contents/Resources/MenuBarIcon.png"
fi

# Create Info.plist. The checked-in PortMonitor/Info.plist is the single
# source of truth for bundle id and versions; stamp those values here so the
# packaged bundle matches what SMAppService (Launch at Login) registers.
SOURCE_INFO_PLIST="PortMonitor/Info.plist"
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$SOURCE_INFO_PLIST")
SHORT_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$SOURCE_INFO_PLIST")
BUNDLE_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$SOURCE_INFO_PLIST")
MIN_SYSTEM=$(/usr/libexec/PlistBuddy -c "Print :LSMinimumSystemVersion" "$SOURCE_INFO_PLIST")

cat > "$BUILD_DIR/$APP_NAME.app/Contents/Info.plist" << EOF
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
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Port Monitor</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$SHORT_VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUNDLE_VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>$MIN_SYSTEM</string>
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
