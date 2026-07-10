#!/usr/bin/env bash
# Remove only artifacts managed by codex-custom-models. Never touches ChatGPT.app/Codex.app.
set -euo pipefail

APP_NAME="ChatGPT OpenRouter Models"
HOME_DIR="${CCM_HOME:-$HOME/.codex-custom}"
PORT="8787"
ASSUME_YES="0"
APPLICATIONS_DIR="${CCM_APPLICATIONS_DIR:-/Applications}"
KEYCHAIN_SERVICE="codex-custom-models-api-key"
PB=/usr/libexec/PlistBuddy

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app-name) APP_NAME="$2"; shift 2 ;;
    --home) HOME_DIR="$2"; shift 2 ;;
    --port) PORT="$2"; shift 2 ;;
    --keychain-service) KEYCHAIN_SERVICE="$2"; shift 2 ;;
    --yes) ASSUME_YES="1"; shift ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

APP="$APPLICATIONS_DIR/${APP_NAME}.app"
PLIST="$HOME/Library/LaunchAgents/com.codexcustommodels.proxy.${PORT}.plist"
LABEL="com.codexcustommodels.proxy.${PORT}"
confirm() {
  local answer
  [[ "$ASSUME_YES" == "1" ]] && return 0
  read -r -p "$1 [y/N]: " answer
  [[ "$answer" == "y" || "$answer" == "Y" ]]
}

if [[ -d "$APP" ]]; then
  [[ "$($PB -c 'Print :CCMManagedBy' "$APP/Contents/Info.plist" 2>/dev/null || true)" == "codex-custom-models" ]] || {
    echo "Refusing to delete an app not managed by this repository: $APP" >&2
    exit 1
  }
  if confirm "Delete managed app $APP?"; then
    pkill -f "${APP}/Contents/MacOS/" 2>/dev/null || true
    rm -rf "$APP"
  fi
fi
if [[ -f "$PLIST" ]] && confirm "Remove the local proxy agent on port $PORT?"; then
  launchctl bootout "gui/$(id -u)" "$PLIST" >/dev/null 2>&1 || launchctl bootout "gui/$(id -u)/${LABEL}" >/dev/null 2>&1 || true
  rm -f "$PLIST"
fi
if [[ -d "$HOME_DIR" ]] && confirm "Delete isolated data $HOME_DIR?"; then rm -rf "$HOME_DIR"; fi
if security find-generic-password -a "$USER" -s "$KEYCHAIN_SERVICE" >/dev/null 2>&1 && confirm "Remove the OpenRouter credential from Keychain?"; then
  security delete-generic-password -a "$USER" -s "$KEYCHAIN_SERVICE" >/dev/null
fi
echo "Done. The official ChatGPT/Codex app and ~/.codex were not touched."
