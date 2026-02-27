#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/RightCmdAgent.app"
BINARY_SOURCE="$ROOT_DIR/.build/release/rightcmd-agent"
PLIST_SOURCE="$ROOT_DIR/deploy/RightCmdAgent-Info.plist"
BINARY_TARGET="$APP_DIR/Contents/MacOS/rightcmd-agent"

if [[ ! -f "$PLIST_SOURCE" ]]; then
  echo "Info.plist template not found: $PLIST_SOURCE" >&2
  exit 1
fi

swift build -c release

mkdir -p "$APP_DIR/Contents/MacOS"
cp "$PLIST_SOURCE" "$APP_DIR/Contents/Info.plist"
cp "$BINARY_SOURCE" "$BINARY_TARGET"
chmod +x "$BINARY_TARGET"

# Ad-hoc signing makes the bundle identity stable enough for permission prompts.
if command -v codesign >/dev/null 2>&1; then
  codesign --force --sign - "$APP_DIR"
fi

echo "Built app bundle: $APP_DIR"
