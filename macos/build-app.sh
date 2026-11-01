#!/usr/bin/env bash
#
# Builds the native SwiftUI app and assembles a self-contained .app bundle in
# dist/. Everything is linked locally: the bundled framework tools never make
# network requests, and the app contains no update-check code.
#
# Usage:
#   ./macos/build-app.sh                 # version from Info.plist
#   VERSION=2.0.0 BUILD_NUMBER=2 ./macos/build-app.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_NAME="NFCToolsGUI"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"

VERSION="${VERSION:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$SCRIPT_DIR/Info.plist")}"
BUILD_NUMBER="${BUILD_NUMBER:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$SCRIPT_DIR/Info.plist")}"

echo "==> Building native release binary (arm64)"
cd "$SCRIPT_DIR"
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"

if [[ "$(uname -m)" != "arm64" ]]; then
    echo "error: this release script expects an Apple silicon build host" >&2
    exit 1
fi

echo "==> Assembling $APP_BUNDLE"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BIN_DIR/NFCToolsGUI" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$SCRIPT_DIR/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
printf 'APPL????' > "$APP_BUNDLE/Contents/PkgInfo"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP_BUNDLE/Contents/Info.plist"

# Icon and runtime resources.
cp "$ROOT_DIR/src/icons/icon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
cp "$ROOT_DIR/dict.dic" "$APP_BUNDLE/Contents/Resources/dict.dic"
ditto "$ROOT_DIR/src/locales" "$APP_BUNDLE/Contents/Resources/locales"
ditto "$ROOT_DIR/framework" "$APP_BUNDLE/Contents/Resources/framework"

COMMIT="$(git -C "$ROOT_DIR" rev-parse --short HEAD 2>/dev/null || echo unknown)"
BUILT_AT="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
cat > "$APP_BUNDLE/Contents/Resources/BuildInfo.txt" <<EOF
version=v$VERSION
builder=Native SwiftUI (arm64, offline)
commit=$COMMIT
built=$BUILT_AT
EOF

echo "==> Relinking bundled dylibs for relocatable loading"
LIB_DIR="$APP_BUNDLE/Contents/Resources/framework/lib"
chmod -R u+w "$LIB_DIR"

install_name_tool -id "@loader_path/libnfc.6.dylib" "$LIB_DIR/libnfc.6.dylib"
install_name_tool -id "@loader_path/libusb-0.1.4.dylib" "$LIB_DIR/libusb-0.1.4.4.4.dylib"
install_name_tool \
    -change "$ROOT_DIR/framework/lib/libusb-0.1.4.dylib" "@loader_path/libusb-0.1.4.dylib" \
    "$LIB_DIR/libusb-0.1.4.4.4.dylib"
install_name_tool -id "@loader_path/libusbpp-0.1.4.dylib" "$LIB_DIR/libusbpp-0.1.4.4.4.dylib"
install_name_tool \
    -change "$ROOT_DIR/framework/lib/libusb-0.1.4.dylib" "@loader_path/libusb-0.1.4.dylib" \
    "$LIB_DIR/libusbpp-0.1.4.4.4.dylib"

for tool in "$APP_BUNDLE/Contents/Resources/framework/bin/"*; do
    name="$(basename "$tool")"
    install_name_tool \
        -change "$ROOT_DIR/framework/lib/libnfc.6.dylib" "@loader_path/../lib/libnfc.6.dylib" \
        "$tool" 2>/dev/null || true
    # Each tool has an executable-bit requirement; keep it after rewriting.
    chmod +x "$tool"
    echo "    tool: $name"
done

echo "==> Ad-hoc signing"
codesign --force --deep --sign - "$APP_BUNDLE" >/dev/null
codesign --verify --deep --strict "$APP_BUNDLE"

echo "==> Verifying linkage and architecture"
file "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
if otool -L "$APP_BUNDLE/Contents/MacOS/$APP_NAME" | grep -E 'Electron|Chromium|URLSession' >/dev/null; then
    echo "error: unexpected framework linked into the app binary" >&2
    exit 1
fi

echo "==> Creating archive"
ZIP_PATH="$DIST_DIR/${APP_NAME}-native-arm64-${VERSION}.zip"
rm -f "$ZIP_PATH" "$ZIP_PATH.sha256"
ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"
shasum -a 256 "$ZIP_PATH" | tee "$ZIP_PATH.sha256"

echo
echo "Built: $APP_BUNDLE"
echo "Archive: $ZIP_PATH"
