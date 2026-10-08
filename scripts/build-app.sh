#!/usr/bin/env bash
# Builds the Falah binary and wraps it into build/Falah.app, signed ad hoc.
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="${CONFIG:-release}"
APP="build/Falah.app"

swift build -c "$CONFIG"
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Falah" "$APP/Contents/MacOS/Falah"
cp Resources/Info.plist "$APP/Contents/Info.plist"

codesign --force --sign - "$APP"
codesign --verify --strict "$APP"

echo "Built $APP"
