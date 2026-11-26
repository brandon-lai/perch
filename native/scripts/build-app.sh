#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p dist/Perch.app/Contents/MacOS dist/Perch.app/Contents/Resources
swift build -c release --arch arm64 --arch x86_64
BIN_DIR="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"
install -S -m 755 "$BIN_DIR/Perch" dist/Perch.app/Contents/MacOS/Perch
cp Info.plist dist/Perch.app/Contents/Info.plist
plutil -lint dist/Perch.app/Contents/Info.plist
codesign --force --sign - dist/Perch.app
codesign --verify --deep --strict dist/Perch.app
lipo -info dist/Perch.app/Contents/MacOS/Perch
VERSION="$(plutil -extract CFBundleShortVersionString raw dist/Perch.app/Contents/Info.plist)"
ZIP="Perch-$VERSION-universal.zip"
ditto -c -k --sequesterRsrc --keepParent dist/Perch.app "dist/$ZIP"
(cd dist && shasum -a 256 "$ZIP" > "$ZIP.sha256")
printf 'Ad-hoc universal artifact: native/dist/%s\n' "$ZIP"
