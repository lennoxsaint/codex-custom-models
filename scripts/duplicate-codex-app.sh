#!/usr/bin/env bash
# Build a separately identified, ad-hoc signed copy of the user's installed
# OpenAI desktop app. Supports the July 2026 unified ChatGPT.app and legacy
# Codex.app. The official source bundle is verified and never modified.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="${1:-ChatGPT OpenRouter Models}"
CODEX_HOME="${2:-$HOME/.codex-custom}"
ELECTRON_USER_DATA_PATH="$CODEX_HOME/electron-user-data"
APPLICATIONS_DIR="${CCM_APPLICATIONS_DIR:-/Applications}"
SOURCE_OVERRIDE="${CCM_SOURCE_APP:-${CCM_CODEX_APP:-}}"
EXPECTED_TEAM_ID="2DC432GLL2"
PB=/usr/libexec/PlistBuddy

[[ "$(uname)" == "Darwin" ]] || { echo "macOS app duplication requires macOS." >&2; exit 1; }
[[ "$APP_NAME" =~ ^[[:alnum:]][[:alnum:]\ ._-]*$ ]] || {
  echo "Invalid app name: $APP_NAME" >&2
  exit 2
}
[[ "$CODEX_HOME" == /* && "$CODEX_HOME" != *$'\n'* ]] || {
  echo "CODEX_HOME must be an absolute single-line path." >&2
  exit 2
}
command -v codesign >/dev/null || { echo "codesign (Xcode Command Line Tools) is required." >&2; exit 1; }
command -v clang >/dev/null || { echo "clang (Xcode Command Line Tools) is required." >&2; exit 1; }

if [[ -n "$SOURCE_OVERRIDE" ]]; then
  SRC="$(python3 "$REPO_DIR/scripts/app_bundle.py" inspect "$SOURCE_OVERRIDE" --field path)"
else
  SRC="$(python3 "$REPO_DIR/scripts/app_bundle.py" detect --applications-dir "$APPLICATIONS_DIR" --field path)"
fi
SRC_EXECUTABLE="$(python3 "$REPO_DIR/scripts/app_bundle.py" inspect "$SRC" --field executable)"
SRC_DISPLAY_NAME="$(python3 "$REPO_DIR/scripts/app_bundle.py" inspect "$SRC" --field display_name)"
SRC_VERSION="$(python3 "$REPO_DIR/scripts/app_bundle.py" inspect "$SRC" --field version)"

if [[ "${CCM_SKIP_SOURCE_SIGNATURE_CHECK:-0}" != "1" ]]; then
  codesign --verify --deep --strict "$SRC" >/dev/null 2>&1 || {
    echo "Refusing to copy an invalid or modified source app: $SRC" >&2
    exit 1
  }
  TEAM_ID="$(codesign -dv --verbose=4 "$SRC" 2>&1 | awk -F= '/^TeamIdentifier=/{print $2; exit}')"
  [[ "$TEAM_ID" == "$EXPECTED_TEAM_ID" ]] || {
    echo "Refusing source signed by unexpected team ${TEAM_ID:-unknown}; expected OpenAI team $EXPECTED_TEAM_ID." >&2
    exit 1
  }
fi

SAFE_USER="$(id -un | tr -cd '[:alnum:]' | tr '[:upper:]' '[:lower:]')"
SAFE_APP="$(printf '%s' "$APP_NAME" | tr -cd '[:alnum:]' | tr '[:upper:]' '[:lower:]')"
[[ -n "$SAFE_APP" ]] || { echo "App name must contain letters or numbers." >&2; exit 2; }
BUNDLE_ID="com.${SAFE_USER}.custommodels.${SAFE_APP}"
DST="${APPLICATIONS_DIR}/${APP_NAME}.app"
STAGE="${APPLICATIONS_DIR}/.${SAFE_APP}.staging.$$.app"
BACKUP="${APPLICATIONS_DIR}/.${SAFE_APP}.backup.$$.app"

cleanup() {
  if [[ -d "$STAGE" ]]; then rm -rf "$STAGE"; fi
  return 0
}
trap cleanup EXIT

if [[ -d "$DST" ]]; then
  MANAGED_BY="$($PB -c 'Print :CCMManagedBy' "$DST/Contents/Info.plist" 2>/dev/null || true)"
  if [[ "$MANAGED_BY" != "codex-custom-models" && "${CCM_REPLACE_UNMANAGED_APP:-0}" != "1" ]]; then
    echo "Refusing to overwrite an app not managed by codex-custom-models: $DST" >&2
    echo "Choose another --app-name or set CCM_REPLACE_UNMANAGED_APP=1 after reviewing that path." >&2
    exit 1
  fi
fi

echo "1/6 verifying and copying ${SRC_DISPLAY_NAME} ${SRC_VERSION} from $SRC"
ditto "$SRC" "$STAGE"

echo "2/6 assigning bundle identity and isolated CODEX_HOME=$CODEX_HOME"
mkdir -p "$ELECTRON_USER_DATA_PATH"
PL="$STAGE/Contents/Info.plist"
"$PB" -c "Set :CFBundleIdentifier $BUNDLE_ID" "$PL"
"$PB" -c "Set :CFBundleName $APP_NAME" "$PL" 2>/dev/null || "$PB" -c "Add :CFBundleName string $APP_NAME" "$PL"
"$PB" -c "Set :CFBundleDisplayName $APP_NAME" "$PL" 2>/dev/null || "$PB" -c "Add :CFBundleDisplayName string $APP_NAME" "$PL"
"$PB" -c "Add :LSEnvironment dict" "$PL" 2>/dev/null || true
"$PB" -c "Set :LSEnvironment:CODEX_HOME $CODEX_HOME" "$PL" 2>/dev/null || "$PB" -c "Add :LSEnvironment:CODEX_HOME string $CODEX_HOME" "$PL"
"$PB" -c "Set :LSEnvironment:CODEX_ELECTRON_USER_DATA_PATH $ELECTRON_USER_DATA_PATH" "$PL" 2>/dev/null || "$PB" -c "Add :LSEnvironment:CODEX_ELECTRON_USER_DATA_PATH string $ELECTRON_USER_DATA_PATH" "$PL"
"$PB" -c "Set :CCMCodexHome $CODEX_HOME" "$PL" 2>/dev/null || "$PB" -c "Add :CCMCodexHome string $CODEX_HOME" "$PL"
"$PB" -c "Set :CCMElectronUserDataPath $ELECTRON_USER_DATA_PATH" "$PL" 2>/dev/null || "$PB" -c "Add :CCMElectronUserDataPath string $ELECTRON_USER_DATA_PATH" "$PL"
"$PB" -c "Set :CCMManagedBy codex-custom-models" "$PL" 2>/dev/null || "$PB" -c "Add :CCMManagedBy string codex-custom-models" "$PL"
"$PB" -c "Set :CCMSourceApp $SRC" "$PL" 2>/dev/null || "$PB" -c "Add :CCMSourceApp string $SRC" "$PL"
"$PB" -c "Set :CCMSourceVersion $SRC_VERSION" "$PL" 2>/dev/null || "$PB" -c "Add :CCMSourceVersion string $SRC_VERSION" "$PL"
REAL_EXECUTABLE="${SRC_EXECUTABLE}.real"
mv "$STAGE/Contents/MacOS/$SRC_EXECUTABLE" "$STAGE/Contents/MacOS/$REAL_EXECUTABLE"
"$PB" -c "Set :CCMRealExecutable $REAL_EXECUTABLE" "$PL" 2>/dev/null || "$PB" -c "Add :CCMRealExecutable string $REAL_EXECUTABLE" "$PL"
clang -Os -Wall -Wextra -framework CoreFoundation "$REPO_DIR/scripts/launcher.c" -o "$STAGE/Contents/MacOS/$SRC_EXECUTABLE"
rm -f "$STAGE/Contents/embedded.provisionprofile"

echo "3/6 patching primary windows to the standard macOS title bar"
python3 - "$STAGE/Contents/Resources/app.asar" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
data = path.read_bytes()
old = b"`hiddenInset`,trafficLightPosition"
new = b"`default`    ,trafficLightPosition"
assert len(old) == len(new), "title-bar patch must preserve byte length"
count = data.count(old)
if count == 0:
    print("WARN: title-bar pattern not found; leaving the app UI unchanged.", file=sys.stderr)
else:
    path.write_bytes(data.replace(old, new))
    print(f"patched {count} primary window(s)", file=sys.stderr)
PY

echo "4/6 disabling Sparkle inside the managed copy"
NATIVE="$STAGE/Contents/Resources/native/sparkle.node"
if [[ -f "$NATIVE" ]]; then
  rm -f "$NATIVE"
else
  echo "WARN: sparkle.node not found; relying on Sparkle Info.plist switches." >&2
fi
"$PB" -c "Set :SUEnableAutomaticChecks false" "$PL" 2>/dev/null || "$PB" -c "Add :SUEnableAutomaticChecks bool false" "$PL"
"$PB" -c "Set :SUScheduledCheckInterval 0" "$PL" 2>/dev/null || "$PB" -c "Add :SUScheduledCheckInterval integer 0" "$PL"
"$PB" -c "Set :SUAutomaticallyUpdate false" "$PL" 2>/dev/null || "$PB" -c "Add :SUAutomaticallyUpdate bool false" "$PL"

echo "5/6 ad-hoc signing and verifying the staged copy"
codesign --force --deep --sign - "$STAGE" >/dev/null 2>&1
xattr -cr "$STAGE" 2>/dev/null || true
codesign --verify --deep --strict "$STAGE" >/dev/null 2>&1 || {
  echo "The staged duplicate failed code-signature verification." >&2
  exit 1
}

echo "6/6 installing $DST and confirming the source stayed valid"
pkill -f "${DST}/Contents/MacOS/" 2>/dev/null || true
sleep 1
if [[ -d "$DST" ]]; then mv "$DST" "$BACKUP"; fi
if ! mv "$STAGE" "$DST"; then
  [[ -d "$BACKUP" ]] && mv "$BACKUP" "$DST"
  exit 1
fi
if ! codesign --verify --deep --strict "$DST" >/dev/null 2>&1; then
  rm -rf "$DST"
  [[ -d "$BACKUP" ]] && mv "$BACKUP" "$DST"
  echo "Installed duplicate failed verification; previous managed copy was restored." >&2
  exit 1
fi
[[ -d "$BACKUP" ]] && rm -rf "$BACKUP"
if [[ "${CCM_SKIP_SOURCE_SIGNATURE_CHECK:-0}" != "1" ]]; then
  codesign --verify --deep --strict "$SRC" >/dev/null 2>&1 || {
    echo "Source verification changed unexpectedly; stop and inspect $SRC." >&2
    exit 1
  }
fi
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$DST" 2>/dev/null || true

echo
echo "Installed: $DST"
echo "Source:    $SRC (${SRC_DISPLAY_NAME} ${SRC_VERSION}, executable ${SRC_EXECUTABLE})"
echo "Bundle ID: $BUNDLE_ID"
echo "CODEX_HOME: $CODEX_HOME"
echo "Electron data: $ELECTRON_USER_DATA_PATH"
echo "Native launcher: $SRC_EXECUTABLE -> $REAL_EXECUTABLE --user-data-dir"
echo "The official source app was verified before and after duplication and was not modified."
