#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift test
bash scripts/build-app.sh
dist/Perch.app/Contents/MacOS/Perch --capture-preview
dist/Perch.app/Contents/MacOS/Perch --capture-settings
dist/Perch.app/Contents/MacOS/Perch --verify-fixture
dist/Perch.app/Contents/MacOS/Perch --verify-tree
dist/Perch.app/Contents/MacOS/Perch --verify-mischief
dist/Perch.app/Contents/MacOS/Perch --verify-climb
dist/Perch.app/Contents/MacOS/Perch --verify-cursor
dist/Perch.app/Contents/MacOS/Perch --verify-pointer
dist/Perch.app/Contents/MacOS/Perch --capture-sprites
dist/Perch.app/Contents/MacOS/Perch --verify-pack Tests/PerchCoreTests/Fixtures/browser.perchpack
