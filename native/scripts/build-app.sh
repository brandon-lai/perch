#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p dist/Perch.app/Contents/MacOS dist/Perch.app/Contents/Resources
swift build -c release --arch arm64 --arch x86_64
BIN_DIR="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"
cp "$BIN_DIR/Perch" dist/Perch.app/Contents/MacOS/Perch
cp Info.plist dist/Perch.app/Contents/Info.plist
plutil -lint dist/Perch.app/Contents/Info.plist
codesign --force --sign - dist/Perch.app
codesign --verify --deep --strict dist/Perch.app
lipo -info dist/Perch.app/Contents/MacOS/Perch
ditto -c -k --sequesterRsrc --keepParent dist/Perch.app dist/Perch-0.1.0-universal.zip
(cd dist && shasum -a 256 Perch-0.1.0-universal.zip > Perch-0.1.0-universal.zip.sha256)
printf 'Ad-hoc universal artifact: native/dist/Perch-0.1.0-universal.zip\n'
