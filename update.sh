#!/usr/bin/env bash
# codex-custom-models — update the fork across Codex releases.
#
# Why this exists: the fork's own auto-updater is disabled on purpose. An ad-hoc
# re-signed copy can never pass Sparkle's signature check (you'd get "the update is
# improperly signed and could not be validated"), and even a successful update would
# overwrite the fork's bundle id / CODEX_HOME / title-bar patch and undo everything.
#
# Your REAL /Applications/Codex.app updates itself normally (untouched, valid OpenAI
# signature). This script simply re-forks from that now-updated Codex.app, preserving
# your app name and CODEX_HOME. Your models/config/proxy live in CODEX_HOME and are
# never touched, so nothing to re-enter.
#
# Usage: ./update.sh ["App Name"]      (default app name: "Codex Custom Models")
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="${1:-Codex Custom Models}"
DST="/Applications/${APP_NAME}.app"
SRC="${CCM_CODEX_APP:-/Applications/Codex.app}"
PB=/usr/libexec/PlistBuddy

[[ "$(uname)" == "Darwin" ]] || { echo "macOS only. Windows/Linux use the CLI profile path (no forked app to update)."; exit 1; }
[ -d "$SRC" ] || { echo "Real Codex not found at $SRC — open Codex and let it update itself first."; exit 1; }
[ -d "$DST" ] || { echo "$DST not found — run ./install.sh first."; exit 1; }

# Preserve the existing fork's CODEX_HOME so models/config/proxy keep working.
HOME_DIR="$("$PB" -c 'Print :LSEnvironment:CODEX_HOME' "$DST/Contents/Info.plist" 2>/dev/null || echo "$HOME/.codex-custom")"

NEW="$("$PB" -c 'Print :CFBundleShortVersionString' "$SRC/Contents/Info.plist" 2>/dev/null || echo '?')"
OLD="$("$PB" -c 'Print :CFBundleShortVersionString' "$DST/Contents/Info.plist" 2>/dev/null || echo '?')"

echo "Real Codex:   $NEW"
echo "Your fork:    $OLD"
echo "CODEX_HOME:   $HOME_DIR"
if [ "$OLD" = "$NEW" ]; then
  echo "Already on $NEW. (Re-fork anyway to re-apply the patches? Continuing.)"
else
  echo "Re-forking $OLD -> $NEW ..."
fi

bash "$REPO_DIR/scripts/duplicate-codex-app.sh" "$APP_NAME" "$HOME_DIR"

echo
echo "Updated '${APP_NAME}' to ${NEW}. Updater stays disabled; window controls work; models/config/proxy untouched."
echo "Open it from /Applications (your Dock pin still points at the same path)."
