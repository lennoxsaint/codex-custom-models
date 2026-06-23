#!/usr/bin/env bash
# Remove the separate-bundle app + proxy agent + isolated home. Your real Codex is untouched.
set -uo pipefail
APP_NAME="${1:-Codex Custom Models}"
HOME_DIR="${CCM_HOME:-$HOME/.codex-custom}"
APP="/Applications/${APP_NAME}.app"
PLIST="$HOME/Library/LaunchAgents/com.codexcustommodels.proxy.plist"
confirm(){ read -r -p "$1 [y/N]: " a; [[ "$a" == y || "$a" == Y ]]; }
pkill -f "${APP_NAME}.app/Contents/MacOS/Codex" 2>/dev/null || true
[[ -f "$PLIST" ]] && { launchctl unload "$PLIST" 2>/dev/null || true; rm -f "$PLIST"; echo "removed proxy agent"; }
[[ -d "$APP" ]] && confirm "Delete $APP?" && rm -rf "$APP"
[[ -d "$HOME_DIR" ]] && confirm "Delete $HOME_DIR?" && rm -rf "$HOME_DIR"
if security find-generic-password -a "$USER" -s codex-custom-models-api-key -w >/dev/null 2>&1 && confirm "Remove API key from Keychain?"; then
  security delete-generic-password -a "$USER" -s codex-custom-models-api-key >/dev/null 2>&1 || true
fi
echo "Done. Your normal Codex (/Applications/Codex.app, ~/.codex) was not touched."
