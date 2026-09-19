#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

# Use the installed Xcode for XCTest and native SDKs without changing xcode-select.
if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

if pgrep -x JevDesktop >/dev/null; then
  echo 'Quit Desktop Voice before building and installing.' >&2
  exit 1
fi

xcrun swift build -c release
JEV_BIN_DIR="$(xcrun swift build -c release --show-bin-path)"
JEV_APP_DIR="$PWD/.build/app/Desktop Voice.app"
JEV_INSTALL_DIR="$HOME/Applications/Desktop Voice.app"
mkdir -p "$JEV_APP_DIR/Contents/MacOS" "$JEV_APP_DIR/Contents/Resources"
cp "$JEV_BIN_DIR/JevDesktop" "$JEV_APP_DIR/Contents/MacOS/JevDesktop"
cp Resources/Info.plist "$JEV_APP_DIR/Contents/Info.plist"
python3 scripts/sign-local.py "$JEV_APP_DIR"
if pgrep -x JevDesktop >/dev/null; then
  echo 'Desktop Voice was opened during the build. Quit it, then run the build again.' >&2
  exit 1
fi
mkdir -p "$HOME/Applications"
ditto "$JEV_APP_DIR" "$JEV_INSTALL_DIR"
codesign --verify --strict "$JEV_INSTALL_DIR"
printf 'Installed: %s\n' "$JEV_INSTALL_DIR"
