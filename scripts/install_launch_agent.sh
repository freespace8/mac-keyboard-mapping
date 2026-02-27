#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TARGET_PATH="${1:-$ROOT_DIR/dist/RightCmdAgent.app}"
CONFIG_PATH="${2:-$HOME/Library/Application Support/RightCmdAgent/config.json}"

PLIST_TEMPLATE="$ROOT_DIR/deploy/com.freespace8.rightcmd.agent.plist"
PLIST_TARGET="$HOME/Library/LaunchAgents/com.freespace8.rightcmd.agent.plist"
LOG_DIR="$HOME/Library/Logs/rightcmd-agent"
STDOUT_PATH="$LOG_DIR/stdout.log"
STDERR_PATH="$LOG_DIR/stderr.log"
CONFIG_DIR="$(dirname "$CONFIG_PATH")"

resolve_binary_path() {
  local target="$1"

  if [[ -d "$target" ]]; then
    local candidate="$target/Contents/MacOS/rightcmd-agent"
    if [[ -x "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi

    echo "App bundle missing executable: $candidate" >&2
    return 1
  fi

  if [[ -x "$target" ]]; then
    echo "$target"
    return 0
  fi

  echo "Target is neither an app bundle nor an executable: $target" >&2
  return 1
}

if [[ ! -f "$PLIST_TEMPLATE" ]]; then
  echo "Template not found: $PLIST_TEMPLATE" >&2
  exit 1
fi

if ! BINARY_PATH="$(resolve_binary_path "$TARGET_PATH")"; then
  echo "Build app first: ./scripts/build_app_bundle.sh" >&2
  exit 1
fi

mkdir -p "$HOME/Library/LaunchAgents" "$LOG_DIR" "$CONFIG_DIR"

/usr/bin/python3 - "$PLIST_TEMPLATE" "$PLIST_TARGET" "$BINARY_PATH" "$CONFIG_PATH" "$STDOUT_PATH" "$STDERR_PATH" <<'PY'
import pathlib
import sys

template = pathlib.Path(sys.argv[1]).read_text()
rendered = (
    template
    .replace("__BINARY_PATH__", sys.argv[3])
    .replace("__CONFIG_PATH__", sys.argv[4])
    .replace("__STDOUT_PATH__", sys.argv[5])
    .replace("__STDERR_PATH__", sys.argv[6])
)
pathlib.Path(sys.argv[2]).write_text(rendered)
PY

if launchctl list com.freespace8.rightcmd.agent >/dev/null 2>&1; then
  launchctl bootout "gui/$(id -u)" "$PLIST_TARGET" || true
fi

launchctl bootstrap "gui/$(id -u)" "$PLIST_TARGET"
launchctl enable "gui/$(id -u)/com.freespace8.rightcmd.agent"
launchctl kickstart -k "gui/$(id -u)/com.freespace8.rightcmd.agent"

echo "LaunchAgent installed: $PLIST_TARGET"
echo "Executable: $BINARY_PATH"
echo "Logs: $STDOUT_PATH and $STDERR_PATH"