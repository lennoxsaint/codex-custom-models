#!/usr/bin/env bash
# Rebuild a managed custom-model app from the latest official ChatGPT/Codex bundle.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPLICATIONS_DIR="${CCM_APPLICATIONS_DIR:-/Applications}"
PB=/usr/libexec/PlistBuddy

if [[ $# -gt 0 ]]; then
  APP_NAME="$1"
else
  APP_NAME=""
  for candidate in "ChatGPT OpenRouter Models" "ChatGPT Custom Models" "Codex Custom Models"; do
    if [[ -d "$APPLICATIONS_DIR/${candidate}.app" ]]; then APP_NAME="$candidate"; break; fi
  done
  [[ -n "$APP_NAME" ]] || APP_NAME="ChatGPT OpenRouter Models"
fi
DST="$APPLICATIONS_DIR/${APP_NAME}.app"

[[ "$(uname)" == "Darwin" ]] || { echo "macOS only; Windows/Linux use the CLI profile path." >&2; exit 1; }
[[ -d "$DST" ]] || { echo "$DST not found; run ./install.sh first." >&2; exit 1; }
[[ "$($PB -c 'Print :CCMManagedBy' "$DST/Contents/Info.plist" 2>/dev/null || true)" == "codex-custom-models" ]] || {
  echo "Refusing to replace an app not managed by this repository: $DST" >&2
  exit 1
}

SOURCE_OVERRIDE="${CCM_SOURCE_APP:-${CCM_CODEX_APP:-}}"
if [[ -n "$SOURCE_OVERRIDE" ]]; then
  SOURCE_APP="$(python3 "$REPO_DIR/scripts/app_bundle.py" inspect "$SOURCE_OVERRIDE" --field path)"
else
  SOURCE_APP="$(python3 "$REPO_DIR/scripts/app_bundle.py" detect --applications-dir "$APPLICATIONS_DIR" --field path)"
fi
HOME_DIR="$($PB -c 'Print :LSEnvironment:CODEX_HOME' "$DST/Contents/Info.plist")"
NEW_VERSION="$(python3 "$REPO_DIR/scripts/app_bundle.py" inspect "$SOURCE_APP" --field version)"
OLD_VERSION="$($PB -c 'Print :CFBundleShortVersionString' "$DST/Contents/Info.plist" 2>/dev/null || echo unknown)"

echo "Official source: $SOURCE_APP ($NEW_VERSION)"
echo "Managed copy:   $DST ($OLD_VERSION)"
echo "CODEX_HOME:     $HOME_DIR"
CCM_SOURCE_APP="$SOURCE_APP" bash "$REPO_DIR/scripts/duplicate-codex-app.sh" "$APP_NAME" "$HOME_DIR"

PORT="$(sed -nE 's|^[[:space:]]*base_url[[:space:]]*=[[:space:]]*"http://127\.0\.0\.1:([0-9]+)/v1".*|\1|p' "$HOME_DIR/config.toml" | head -1)"
PORT="${PORT:-8787}"
bash "$REPO_DIR/scripts/verify.sh" --app-name "$APP_NAME" --home "$HOME_DIR" --port "$PORT" --skip-marker

echo "Updated $APP_NAME from $OLD_VERSION to $NEW_VERSION. Models, credentials, and isolated history were preserved."
