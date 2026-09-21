#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
CHECK_DIR="$(mktemp -d)"
trap 'rm -rf "$CHECK_DIR"' EXIT
swiftc -parse-as-library Sources/JevDesktop/HotKey.swift Sources/JevDesktop/SpeechInput.swift Sources/JevDesktop/WakePhrase.swift Tests/DesktopChecks/main.swift -o "$CHECK_DIR/check-desktop"
"$CHECK_DIR/check-desktop"
