#!/usr/bin/env bash
# Build a TRUE separate-bundle duplicate of Codex with WORKING window controls.
#
# Why this exists: launching a 2nd instance of the same Codex bundle (open -n
# --user-data-dir) leaves the duplicate's red/yellow/green traffic-lights dead —
# macOS ties window-control/activation to the bundle ID, so two instances of the
# SAME bundle get conflated. The fix is a genuinely separate app bundle (its own
# CFBundleIdentifier), copied from your own local Codex.app and ad-hoc re-signed.
#
# One extra wrinkle on the inset title bar: in a duplicated bundle the native
# traffic-lights of `titleBarStyle:hiddenInset` render with a click hit-area
# offset (you have to click slightly above the dots). Switching the primary
# windows to the STANDARD title bar (`titleBarStyle:default`) gives OS-managed
# buttons whose hit-areas are correct. Tradeoff: a slim standard title bar strip.
#
# Nothing here redistributes OpenAI software: it copies YOUR local install and
# re-signs the copy ad-hoc for local use. Tested on Codex 26.616.71553.
set -euo pipefail

APP_NAME="${1:-Codex Custom Models}"
CODEX_HOME="${2:-$HOME/.codex-custom}"
SRC="${CCM_CODEX_APP:-/Applications/Codex.app}"
DST="/Applications/${APP_NAME}.app"
BUNDLE_ID="com.$(id -un | tr -cd '[:alnum:]' | tr '[:upper:]' '[:lower:]').codexcustommodels"

[ -d "$SRC" ] || { echo "Codex.app not found at $SRC — install Codex first."; exit 1; }
command -v codesign >/dev/null || { echo "codesign (Xcode CLT) required."; exit 1; }

echo "1/5 copying $SRC -> $DST"
# quit any running copy, then copy
pkill -f "${APP_NAME}.app/Contents/MacOS/Codex" 2>/dev/null || true
sleep 1
rm -rf "$DST"
ditto "$SRC" "$DST"

echo "2/5 rebranding bundle + injecting CODEX_HOME=$CODEX_HOME"
PB=/usr/libexec/PlistBuddy; PL="$DST/Contents/Info.plist"
"$PB" -c "Set :CFBundleIdentifier $BUNDLE_ID" "$PL"
"$PB" -c "Set :CFBundleName $APP_NAME" "$PL" 2>/dev/null || "$PB" -c "Add :CFBundleName string $APP_NAME" "$PL"
"$PB" -c "Set :CFBundleDisplayName $APP_NAME" "$PL" 2>/dev/null || "$PB" -c "Add :CFBundleDisplayName string $APP_NAME" "$PL"
"$PB" -c "Delete :LSEnvironment" "$PL" 2>/dev/null || true
"$PB" -c "Add :LSEnvironment dict" "$PL"
"$PB" -c "Add :LSEnvironment:CODEX_HOME string $CODEX_HOME" "$PL"
rm -f "$DST/Contents/embedded.provisionprofile"   # invalid for an ad-hoc re-sign

echo "3/5 patching window controls (primary windows -> standard title bar)"
# Byte-preserving edit: `hiddenInset` -> `default` ONLY for primary windows
# (identified by the trailing ,trafficLightPosition). The asar header is
# unchanged, so ElectronAsarIntegrity (a header hash) still validates.
python3 - "$DST/Contents/Resources/app.asar" <<'PY'
import sys
p = sys.argv[1]
b = open(p, "rb").read()
old = b"`hiddenInset`,trafficLightPosition"
new = b"`default`    ,trafficLightPosition"   # default(7)+`` + 4 spaces == hiddenInset(11)+`` ; byte-preserving
assert len(old) == len(new), "patch not byte-preserving"
n = b.count(old)
if n == 0:
    sys.stderr.write("WARN: primary-window titlebar pattern not found (Codex changed its minified code?). "
                     "Skipping titlebar fix — buttons may have the hit-area offset. See TROUBLESHOOTING.md\n")
else:
    b = b.replace(old, new)
    open(p, "wb").write(b)
    sys.stderr.write(f"patched {n} primary window(s) to standard title bar\n")
PY

echo "4/5 sourcing your local Codex icon (no vendor asset shipped) — keeping Codex icon"
# (icon stays the user's own local Codex icon, copied with the bundle)

echo "5/5 ad-hoc re-sign + de-quarantine + register"
codesign --force --deep --sign - "$DST" >/dev/null 2>&1
xattr -cr "$DST" 2>/dev/null || true
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$DST" 2>/dev/null || true

echo
echo "Done -> $DST  (bundle id: $BUNDLE_ID, CODEX_HOME: $CODEX_HOME)"
echo "Open it from /Applications and drag to your Dock. Window buttons work; it uses a standard title bar."
