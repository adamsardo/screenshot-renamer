#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${VERSION:?Set VERSION to the release version, e.g. 0.1.0-preview.1}"
case "$VERSION" in *[!a-zA-Z0-9.-]*) echo 'Invalid version' >&2; exit 1;; esac
export VERSION
./scripts/build.sh
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/screenshot-renamer-dmg.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
ditto "dist/Screenshot Renamer.app" "$STAGE/Screenshot Renamer.app"
ln -s /Applications "$STAGE/Applications"
cp LICENSE "$STAGE/LICENSE.txt"
printf 'Drag Screenshot Renamer to Applications.\nRequires macOS 27+, Apple silicon and Apple Intelligence for suggestions.\n\nThis preview is ad-hoc signed unless the release notes explicitly say notarised.\nSee https://github.com/adamsardo/screenshot-renamer for installation and privacy details.\n' > "$STAGE/Read Me.txt"
DMG="dist/Screenshot-Renamer-${VERSION}-arm64.dmg"
hdiutil create -volname "Screenshot Renamer" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
if [ -n "${SIGNING_IDENTITY:-}" ] && [ "$SIGNING_IDENTITY" != '-' ]; then
  codesign --force --sign "$SIGNING_IDENTITY" --timestamp "$DMG"
fi
if [ -n "${NOTARY_PROFILE:-}" ]; then
  case "${SIGNING_IDENTITY:-}" in 'Developer ID Application:'*) ;; *) echo 'Notarisation requires Developer ID Application signing.' >&2; exit 1;; esac
  xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG"
  xcrun stapler validate "$DMG"
  spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"
fi
(cd dist && shasum -a 256 "$(basename "$DMG")" > "$(basename "$DMG").sha256")
printf '\nPackaged %s\n' "$DMG"
