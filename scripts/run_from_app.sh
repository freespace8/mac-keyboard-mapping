#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="${1:-$ROOT_DIR/dist/RightCmdAgent.app}"
CONFIG_PATH="${2:-$HOME/Library/Application Support/RightCmdAgent/config.json}"
BINARY_PATH="$APP_PATH/Contents/MacOS/rightcmd-agent"

if [[ ! -x "$BINARY_PATH" ]]; then
  echo "Executable not found in app bundle: $BINARY_PATH" >&2
  echo "Build app first: ./scripts/build_app_bundle.sh" >&2
  exit 1
fi

RIGHTCMD_CONFIG="$CONFIG_PATH" "$BINARY_PATH"
