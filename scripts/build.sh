#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${VERSION:-$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || true)}"
VERSION="${VERSION:-0.1.0-preview.1}"
APP="dist/Screenshot Renamer.app"
IDENTITY="${SIGNING_IDENTITY:--}"
swift build -c release --arch arm64
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
BIN_DIR="$(swift build -c release --arch arm64 --show-bin-path)"
cp "$BIN_DIR/ScreenshotRenamer" "$APP/Contents/MacOS/ScreenshotRenamer"
/usr/libexec/PlistBuddy -c 'Clear dict' "$APP/Contents/Info.plist" >/dev/null 2>&1 || true
/usr/libexec/PlistBuddy "$APP/Contents/Info.plist" \
 -c 'Add CFBundleIdentifier string io.github.adamsardo.screenshot-renamer' \
 -c 'Add CFBundleName string Screenshot Renamer' \
 -c 'Add CFBundleDisplayName string Screenshot Renamer' \
 -c 'Add CFBundleExecutable string ScreenshotRenamer' \
 -c 'Add CFBundlePackageType string APPL' \
 -c "Add CFBundleShortVersionString string ${VERSION%%-*}" \
 -c 'Add CFBundleVersion string 1' \
 -c 'Add LSMinimumSystemVersion string 27.0' \
 -c 'Add NSHighResolutionCapable bool true' \
 -c 'Add NSSupportsAutomaticTermination bool false' \
 -c 'Add NSPrincipalClass string NSApplication' \
 -c 'Add CFBundleIconFile string AppIcon' \
 -c 'Add NSHumanReadableCopyright string Copyright © 2026 Adam Sardo. MIT License.'
if [ -f Resources/AppIcon.icns ]; then cp Resources/AppIcon.icns "$APP/Contents/Resources/"; fi
cp LICENSE "$APP/Contents/Resources/LICENSE.txt"
if [ "$IDENTITY" = '-' ]; then
  codesign --force --sign - --options runtime --entitlements Resources/App.entitlements "$APP"
else
  codesign --force --sign "$IDENTITY" --timestamp --options runtime --entitlements Resources/App.entitlements "$APP"
fi
codesign --verify --deep --strict --verbose=2 "$APP"
printf '\nBuilt %s (%s)\n' "$APP" "$VERSION"
