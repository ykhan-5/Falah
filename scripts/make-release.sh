#!/usr/bin/env bash
# Builds a universal (Apple silicon + Intel) Falah.app, signs it ad hoc, and zips it
# to build/Falah.zip for a GitHub release.
#
# `swift build --arch arm64 --arch x86_64` needs Xcode's build system, so each
# architecture is built separately with --triple and the binaries are merged with lipo.
set -euo pipefail

cd "$(dirname "$0")/.."

APP="build/Falah.app"
ZIP="build/Falah.zip"
MIN_MACOS="14.0"

for arch in arm64 x86_64; do
    echo "==> Building $arch"
    swift build -c release --triple "$arch-apple-macosx$MIN_MACOS"
done

ARM_BIN="$(swift build -c release --triple "arm64-apple-macosx$MIN_MACOS" --show-bin-path)/Falah"
X86_BIN="$(swift build -c release --triple "x86_64-apple-macosx$MIN_MACOS" --show-bin-path)/Falah"

echo "==> Assembling $APP"
rm -rf "$APP" "$ZIP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
lipo -create "$ARM_BIN" "$X86_BIN" -output "$APP/Contents/MacOS/Falah"
cp Resources/Info.plist "$APP/Contents/Info.plist"

echo "==> Signing (ad hoc)"
codesign --force --sign - "$APP"
codesign --verify --strict "$APP"

echo "==> Zipping"
ditto -c -k --keepParent "$APP" "$ZIP"

lipo -info "$APP/Contents/MacOS/Falah"
echo "Version: $(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
echo "Built $ZIP ($(du -h "$ZIP" | cut -f1))"
