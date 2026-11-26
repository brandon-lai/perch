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
ditto -c -k --sequesterRsrc --keepParent dist/Perch.app dist/Perch-0.1.0-notarized.zip
(cd dist && shasum -a 256 Perch-0.1.0-notarized.zip > Perch-0.1.0-notarized.zip.sha256)
