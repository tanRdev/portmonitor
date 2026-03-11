#!/bin/bash
set -euo pipefail

PROJECT_NAME="PortMonitor"
BUILD_DIR="build"
APP_PATH="$BUILD_DIR/$PROJECT_NAME.app"
CONTENTS_PATH="$APP_PATH/Contents"
MACOS_PATH="$CONTENTS_PATH/MacOS"
RESOURCES_PATH="$CONTENTS_PATH/Resources"
ARM64_BUILD_PATH="$BUILD_DIR/swiftpm-arm64"
X86_64_BUILD_PATH="$BUILD_DIR/swiftpm-x86_64"
VERSION=${VERSION:-${GITHUB_REF_NAME:-1.0.0}}

if [[ "$VERSION" == v* ]]; then
    VERSION="${VERSION#v}"
fi

echo "Building $PROJECT_NAME..."

# Clean previous builds
rm -rf "$BUILD_DIR"
mkdir -p "$MACOS_PATH" "$RESOURCES_PATH"

# Build separate binaries for Apple Silicon and Intel, then merge them
swift build -c release --arch arm64 --build-path "$ARM64_BUILD_PATH" -j 2
swift build -c release --arch x86_64 --build-path "$X86_64_BUILD_PATH" -j 2

ARM64_BIN_PATH=$(swift build -c release --arch arm64 --build-path "$ARM64_BUILD_PATH" --show-bin-path)
X86_64_BIN_PATH=$(swift build -c release --arch x86_64 --build-path "$X86_64_BUILD_PATH" --show-bin-path)

# Create a universal executable
lipo -create \
    "$ARM64_BIN_PATH/$PROJECT_NAME" \
    "$X86_64_BIN_PATH/$PROJECT_NAME" \
    -output "$MACOS_PATH/$PROJECT_NAME"

# Create Info.plist
cat > "$CONTENTS_PATH/Info.plist" << EOF
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
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>PortMonitor</string>
    <key>LSMinimumSystemVersion</key>
    <string>26.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# Copy runtime resources
if [ -f "assets/icons/port-grid/port-grid-tray-44.png" ]; then
    cp "assets/icons/port-grid/port-grid-tray-44.png" "$RESOURCES_PATH/MenuBarIcon.png"
elif [ -f "PortMonitor/Assets/MenuBarIcon.png" ]; then
    cp "PortMonitor/Assets/MenuBarIcon.png" "$RESOURCES_PATH/MenuBarIcon.png"
fi

# Build and attach app icon
ICONSET_DIR="$BUILD_DIR/AppIcon.iconset"
mkdir -p "$ICONSET_DIR"
cp "assets/icons/port-grid/port-grid-16.png" "$ICONSET_DIR/icon_16x16.png"
cp "assets/icons/port-grid/port-grid-32.png" "$ICONSET_DIR/icon_16x16@2x.png"
cp "assets/icons/port-grid/port-grid-32.png" "$ICONSET_DIR/icon_32x32.png"
cp "assets/icons/port-grid/port-grid-64.png" "$ICONSET_DIR/icon_32x32@2x.png"
cp "assets/icons/port-grid/port-grid-128.png" "$ICONSET_DIR/icon_128x128.png"
cp "assets/icons/port-grid/port-grid-256.png" "$ICONSET_DIR/icon_128x128@2x.png"
cp "assets/icons/port-grid/port-grid-256.png" "$ICONSET_DIR/icon_256x256.png"
cp "assets/icons/port-grid/port-grid-512.png" "$ICONSET_DIR/icon_256x256@2x.png"
cp "assets/icons/port-grid/port-grid-512.png" "$ICONSET_DIR/icon_512x512.png"
cp "assets/icons/port-grid/port-grid-1024.png" "$ICONSET_DIR/icon_512x512@2x.png"
iconutil --convert icns "$ICONSET_DIR" --output "$RESOURCES_PATH/AppIcon.icns"

cat > "$CONTENTS_PATH/PkgInfo" << 'EOF'
APPL????
EOF

echo "Build complete: $APP_PATH"
echo ""
echo "To run:"
echo "  open '$APP_PATH'"
