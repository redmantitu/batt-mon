#!/bin/zsh
# Builds ScreenOnTime.app (ad-hoc signed). Usage: scripts/build.sh [--install]
set -euo pipefail
cd "$(dirname "$0")/.."
APP=build/ScreenOnTime.app
rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS"
swiftc -O ScreenOnTime.swift -o "$APP/Contents/MacOS/ScreenOnTime"
cp Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
echo "Built $APP"
if [[ "${1:-}" == "--install" ]]; then
  pkill -x ScreenOnTime || true
  rm -rf /Applications/ScreenOnTime.app
  cp -R "$APP" /Applications/
  open /Applications/ScreenOnTime.app
  echo "Installed to /Applications"
fi
