#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
exec swift run jev-realtime "$@"
