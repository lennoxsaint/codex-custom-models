#!/usr/bin/env bash
# Remove the custom instance WITHOUT touching your normal ~/.codex. Prompts before each step.
set -uo pipefail
HOME_DIR="${CCM_HOME:-$HOME/.codex-custom}"
APP_NAME="${1:-Codex Custom Models}"
APP="/Applications/${APP_NAME}.app"
confirm() { read -r -p "$1 [y/N]: " a; [[ "$a" == "y" || "$a" == "Y" ]]; }
launchctl remove com.codexcustommodels.proxy >/dev/null 2>&1 || true
if [[ -d "$APP" ]] && confirm "Delete $APP?"; then rm -rf "$APP"; fi
if [[ -d "$HOME_DIR" ]] && confirm "Delete isolated home $HOME_DIR?"; then rm -rf "$HOME_DIR"; fi
if security find-generic-password -a "$USER" -s codex-custom-models-api-key -w >/dev/null 2>&1 && confirm "Remove API key from Keychain?"; then
  security delete-generic-password -a "$USER" -s codex-custom-models-api-key >/dev/null 2>&1 || true
fi
echo "Done. Your normal ~/.codex was not touched."
