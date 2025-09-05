#!/usr/bin/env bash
set -euo pipefail

PLIST_LABEL="com.brennan.bearminder"
DEST_DIR="$HOME/Library/LaunchAgents"
DEST_PLIST="$DEST_DIR/${PLIST_LABEL}.plist"

if launchctl list | grep -q "$PLIST_LABEL"; then
  launchctl stop "$PLIST_LABEL" || true
  launchctl unload "$DEST_PLIST" || true
fi

if [[ -f "$DEST_PLIST" ]]; then
  rm -f "$DEST_PLIST"
  echo "Removed $DEST_PLIST"
fi

echo "LaunchAgent '$PLIST_LABEL' has been unloaded and removed."
