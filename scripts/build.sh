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
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9.-]+)?$ ]]; then
  echo 'Use a semantic version such as 0.1.0-preview.1' >&2
  exit 1
fi
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>io.github.adamsardo.screenshot-renamer</string>
<key>CFBundleName</key><string>Screenshot Renamer</string>
<key>CFBundleDisplayName</key><string>Screenshot Renamer</string>
<key>CFBundleExecutable</key><string>ScreenshotRenamer</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>${VERSION%%-*}</string>
<key>CFBundleVersion</key><string>$(git rev-list --count HEAD)</string>
<key>SourceRevision</key><string>$(git rev-parse HEAD)</string>
<key>ReleaseVersion</key><string>$VERSION</string>
<key>LSMinimumSystemVersion</key><string>27.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSSupportsAutomaticTermination</key><false/>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>NSHumanReadableCopyright</key><string>Copyright © 2026 Adam Sardo. MIT License.</string>
</dict></plist>
PLIST
plutil -lint "$APP/Contents/Info.plist"
if [ -f Resources/AppIcon.icns ]; then cp Resources/AppIcon.icns "$APP/Contents/Resources/"; fi
cp LICENSE "$APP/Contents/Resources/LICENSE.txt"
if [ "$IDENTITY" = '-' ]; then
  codesign --force --sign - --options runtime --entitlements Resources/App.entitlements "$APP"
else
  codesign --force --sign "$IDENTITY" --timestamp --options runtime --entitlements Resources/App.entitlements "$APP"
fi
codesign --verify --deep --strict --verbose=2 "$APP"
printf '\nBuilt %s (%s)\n' "$APP" "$VERSION"
