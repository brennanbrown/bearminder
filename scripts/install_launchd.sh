#!/usr/bin/env bash
set -euo pipefail

# Install a launchd LaunchAgent to run BearMinder scheduler at login on macOS.
# This writes a per-user plist to ~/Library/LaunchAgents/com.brennan.bearminder.plist
# and loads it with launchctl.

PLIST_LABEL="com.brennan.bearminder"
DEST_DIR="$HOME/Library/LaunchAgents"
DEST_PLIST="$DEST_DIR/${PLIST_LABEL}.plist"

# Resolve repository root (script path -> repo)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Prefer repo .venv python, then python3, then python
PY_BIN="$REPO_ROOT/.venv/bin/python"
if [[ ! -x "$PY_BIN" ]]; then
  if command -v python3 >/dev/null 2>&1; then
    PY_BIN="python3"
  else
    PY_BIN="python"
  fi
fi

mkdir -p "$DEST_DIR"
mkdir -p "$REPO_ROOT/data"

# Generate plist content
cat > "$DEST_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>${PLIST_LABEL}</string>

    <key>ProgramArguments</key>
    <array>
      <string>${PY_BIN}</string>
      <string>-m</string>
      <string>bearminder.main</string>
      <string>schedule</string>
    </array>

    <key>WorkingDirectory</key>
    <string>${REPO_ROOT}</string>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <dict>
      <key>SuccessfulExit</key>
      <false/>
    </dict>

    <key>StandardOutPath</key>
    <string>${REPO_ROOT}/data/launchd.out.log</string>

    <key>StandardErrorPath</key>
    <string>${REPO_ROOT}/data/launchd.err.log</string>
  </dict>
</plist>
PLIST

# Unload if already loaded, ignore errors
launchctl unload "$DEST_PLIST" >/dev/null 2>&1 || true

# Load new agent
launchctl load "$DEST_PLIST"
launchctl start "$PLIST_LABEL" || true

echo "Installed and started LaunchAgent: $DEST_PLIST"
echo "Logs: $REPO_ROOT/data/launchd.out.log (stdout), $REPO_ROOT/data/launchd.err.log (stderr)"
