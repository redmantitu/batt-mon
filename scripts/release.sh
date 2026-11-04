#!/bin/zsh
# Builds a universal (arm64 + x86_64) ScreenOnTime.app and zips it for a release.
# Usage: scripts/release.sh   -> dist/ScreenOnTime-<version>.zip and prints its sha256
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Info.plist)
APP=dist/ScreenOnTime.app
rm -rf dist; mkdir -p "$APP/Contents/MacOS" dist/tmp
for arch in arm64 x86_64; do
  swiftc -O -target $arch-apple-macos13.0 ScreenOnTime.swift -o dist/tmp/sot-$arch
done
lipo -create dist/tmp/sot-arm64 dist/tmp/sot-x86_64 -output "$APP/Contents/MacOS/ScreenOnTime"
rm -rf dist/tmp
cp Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
ZIP="dist/ScreenOnTime-$VERSION.zip"
ditto -c -k --keepParent "$APP" "$ZIP"
echo "$ZIP"
shasum -a 256 "$ZIP"
