#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${DEVELOPER_ID_APPLICATION:?Set an explicitly chosen Developer ID Application identity}"
: "${NOTARY_PROFILE:?Set a previously configured notarytool keychain profile}"
case "$DEVELOPER_ID_APPLICATION" in
  "Developer ID Application:"*) ;;
  *) echo "Use a Developer ID Application identity, not an arbitrary local identity."; exit 1 ;;
esac
test -d dist/Perch.app
codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID_APPLICATION" dist/Perch.app
codesign --verify --deep --strict --verbose=2 dist/Perch.app
ditto -c -k --sequesterRsrc --keepParent dist/Perch.app dist/Perch-notarization.zip
xcrun notarytool submit dist/Perch-notarization.zip --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple dist/Perch.app
xcrun stapler validate dist/Perch.app
spctl --assess --type execute --verbose=2 dist/Perch.app
VERSION="$(plutil -extract CFBundleShortVersionString raw dist/Perch.app/Contents/Info.plist)"
ZIP="Perch-$VERSION-notarized.zip"
ditto -c -k --sequesterRsrc --keepParent dist/Perch.app "dist/$ZIP"
(cd dist && shasum -a 256 "$ZIP" > "$ZIP.sha256")
