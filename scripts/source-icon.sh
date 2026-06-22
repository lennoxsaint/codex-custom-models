#!/usr/bin/env bash
# Copy the app icon from the user's OWN local Codex install. Never download/ship a vendor icon.
# Fallback: convert the bundled neutral PNG to .icns. Non-fatal.
set -euo pipefail
OUT="${1:?usage: source-icon.sh <out.icns>}"
REPO_DIR="${CCM_REPO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SRC="/Applications/Codex.app/Contents/Resources/AppIcon.icns"
if [[ -f "$SRC" ]]; then
  cp "$SRC" "$OUT"; echo "icon: sourced from your local Codex.app"; exit 0
fi
FALLBACK="$REPO_DIR/assets/fallback-icon.png"
if [[ -f "$FALLBACK" ]] && command -v sips >/dev/null 2>&1; then
  TMP="$(mktemp -d)/icon.iconset"; mkdir -p "$TMP"
  for s in 16 32 64 128 256 512; do
    sips -z $s $s "$FALLBACK" --out "$TMP/icon_${s}x${s}.png" >/dev/null 2>&1 || true
    sips -z $((s*2)) $((s*2)) "$FALLBACK" --out "$TMP/icon_${s}x${s}@2x.png" >/dev/null 2>&1 || true
  done
  iconutil -c icns "$TMP" -o "$OUT" 2>/dev/null && { echo "icon: neutral fallback"; exit 0; }
fi
echo "icon: none found (app will use default); non-fatal"; exit 0
