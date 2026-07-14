#!/usr/bin/env bash
# Strict structural, proxy, and optional paid marker-turn verification.
set -euo pipefail

APP_NAME="ChatGPT OpenRouter Models"
HOME_DIR="$HOME/.codex-custom"
PORT="${CCM_PROXY_PORT:-8787}"
CODEX_BIN="$(command -v codex || true)"
SKIP_MARKER="0"
SLUG=""
APPLICATIONS_DIR="${CCM_APPLICATIONS_DIR:-/Applications}"
PB=/usr/libexec/PlistBuddy

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app-name) APP_NAME="$2"; shift 2 ;;
    --home) HOME_DIR="$2"; shift 2 ;;
    --port) PORT="$2"; shift 2 ;;
    --codex-bin) CODEX_BIN="$2"; shift 2 ;;
    --slug) SLUG="$2"; shift 2 ;;
    --skip-marker) SKIP_MARKER="1"; shift ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

APP="$APPLICATIONS_DIR/${APP_NAME}.app"
[[ -d "$APP" ]] || { echo "FAIL: installed app missing: $APP" >&2; exit 1; }
codesign --verify --deep --strict "$APP" >/dev/null 2>&1 || { echo "FAIL: duplicate code signature is invalid" >&2; exit 1; }
PLIST="$APP/Contents/Info.plist"
DISPLAY="$($PB -c 'Print :CFBundleDisplayName' "$PLIST")"
BUNDLE_ID="$($PB -c 'Print :CFBundleIdentifier' "$PLIST")"
MANAGED_BY="$($PB -c 'Print :CCMManagedBy' "$PLIST")"
APP_HOME="$($PB -c 'Print :LSEnvironment:CODEX_HOME' "$PLIST")"
APP_ELECTRON_HOME="$($PB -c 'Print :LSEnvironment:CODEX_ELECTRON_USER_DATA_PATH' "$PLIST")"
EXECUTABLE="$($PB -c 'Print :CFBundleExecutable' "$PLIST")"
REAL_EXECUTABLE="$($PB -c 'Print :CCMRealExecutable' "$PLIST")"
[[ "$DISPLAY" == "$APP_NAME" ]] || { echo "FAIL: display name mismatch: $DISPLAY" >&2; exit 1; }
[[ "$BUNDLE_ID" != "com.openai.codex" ]] || { echo "FAIL: duplicate reused the official bundle identifier" >&2; exit 1; }
[[ "$MANAGED_BY" == "codex-custom-models" ]] || { echo "FAIL: managed-app marker is missing" >&2; exit 1; }
[[ "$APP_HOME" == "$HOME_DIR" ]] || { echo "FAIL: CODEX_HOME mismatch: $APP_HOME" >&2; exit 1; }
[[ "$APP_ELECTRON_HOME" == "$HOME_DIR/electron-user-data" ]] || { echo "FAIL: Electron user-data path is not isolated: $APP_ELECTRON_HOME" >&2; exit 1; }
[[ -x "$APP/Contents/MacOS/$EXECUTABLE" ]] || { echo "FAIL: duplicate executable missing: $EXECUTABLE" >&2; exit 1; }
[[ -x "$APP/Contents/MacOS/$REAL_EXECUTABLE" ]] || { echo "FAIL: copied real executable missing: $REAL_EXECUTABLE" >&2; exit 1; }
file "$APP/Contents/MacOS/$EXECUTABLE" | grep -q 'Mach-O' || { echo "FAIL: bundle launcher is not a native macOS executable" >&2; exit 1; }
[[ "$($PB -c 'Print :CCMCodexHome' "$PLIST")" == "$HOME_DIR" ]] || { echo "FAIL: native launcher CODEX_HOME metadata mismatch" >&2; exit 1; }
[[ "$($PB -c 'Print :CCMElectronUserDataPath' "$PLIST")" == "$HOME_DIR/electron-user-data" ]] || { echo "FAIL: native launcher user-data metadata mismatch" >&2; exit 1; }
[[ ! -e "$APP/Contents/Resources/native/sparkle.node" ]] || { echo "FAIL: updater native module still present" >&2; exit 1; }
[[ "$($PB -c 'Print :SUEnableAutomaticChecks' "$PLIST")" == "false" ]] || { echo "FAIL: automatic checks are still enabled" >&2; exit 1; }

HEALTH="$(curl -fsS "http://127.0.0.1:${PORT}/health")" || { echo "FAIL: proxy not healthy on port $PORT" >&2; exit 1; }
printf '%s' "$HEALTH" | node -e '
let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{
  const j=JSON.parse(s);
  if(j.ok!==true || j.service!=="codex-custom-models-proxy" || !Array.isArray(j.aliases) || j.aliases.length===0) process.exit(1);
});' || { echo "FAIL: wrong or empty service is listening on port $PORT" >&2; exit 1; }

MODELS="$(curl -fsS "http://127.0.0.1:${PORT}/v1/models")"
EXPECTED_MODELS_FILE="$HOME_DIR/custom-models/models.json"
[[ -f "$EXPECTED_MODELS_FILE" ]] || { echo "FAIL: installed models file missing: $EXPECTED_MODELS_FILE" >&2; exit 1; }
printf '%s' "$MODELS" | node -e '
const fs = require("node:fs");
const expectedRaw = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
const expected = (Array.isArray(expectedRaw) ? expectedRaw : expectedRaw.models).map((model) => [model.slug, model.target]);
let input = "";
process.stdin.on("data", (chunk) => { input += chunk; });
process.stdin.on("end", () => {
  const actual = JSON.parse(input).data.map((model) => [model.id, model.target_model]);
  if (JSON.stringify(actual) !== JSON.stringify(expected)) process.exit(1);
});
' "$EXPECTED_MODELS_FILE" || { echo "FAIL: proxy model mappings do not match the installed member pack" >&2; exit 1; }
printf '%s' "$MODELS" | node -e '
let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{
  const j=JSON.parse(s); if(!Array.isArray(j.data)||j.data.length===0) process.exit(1);
  console.log(j.data.map(m=>`${m.id} -> ${m.target_model}`).join("\n"));
});'

if [[ -z "$SLUG" ]]; then
  SLUG="$(node -e 'const m=require(process.argv[1]);const l=Array.isArray(m)?m:m.models;process.stdout.write(l[0].slug)' "$HOME_DIR/custom-models/models.json")"
fi

if [[ "$SKIP_MARKER" == "0" ]]; then
  [[ -x "$CODEX_BIN" ]] || { echo "FAIL: Codex CLI is required for the marker turn" >&2; exit 1; }
  VERIFY_CONFIG_BACKUP="$HOME_DIR/config.verify-backup.$$"
  cp -p "$HOME_DIR/config.toml" "$VERIFY_CONFIG_BACKUP"
  BEFORE_LINES="$(wc -l < "$HOME_DIR/proxy.log" 2>/dev/null || echo 0)"
  set +e
  OUT="$(CODEX_HOME="$HOME_DIR" "$CODEX_BIN" exec --skip-git-repo-check --model "$SLUG" 'Reply with exactly: OK-CUSTOM-MODELS' 2>&1)"
  MARKER_EXIT=$?
  set -e
  cp -p "$VERIFY_CONFIG_BACKUP" "$HOME_DIR/config.toml"
  rm -f "$VERIFY_CONFIG_BACKUP"
  if (( MARKER_EXIT != 0 )); then
    printf '%s\n' "$OUT" | tail -20 >&2
    echo "FAIL: marker turn failed" >&2
    exit 1
  fi
  printf '%s\n' "$OUT" | grep -q "OK-CUSTOM-MODELS" || {
    printf '%s\n' "$OUT" | tail -20 >&2
    echo "FAIL: marker text was not returned" >&2
    exit 1
  }
  AFTER_LINES="$(wc -l < "$HOME_DIR/proxy.log" 2>/dev/null || echo 0)"
  (( AFTER_LINES > BEFORE_LINES )) || { echo "FAIL: marker turn did not create proxy evidence" >&2; exit 1; }
  echo "Marker turn: PASS"
else
  echo "Marker turn: SKIPPED (structural verification only)"
fi

echo "App bundle: PASS ($APP, bundle $BUNDLE_ID, executable $EXECUTABLE)"
echo "Proxy and model catalog: PASS (127.0.0.1:${PORT})"
