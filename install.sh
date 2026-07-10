#!/usr/bin/env bash
# Agent-friendly installer for an isolated custom-model copy of OpenAI's desktop app.
# Supports the July 2026 unified ChatGPT.app and the legacy Codex.app.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROVIDER=""
MODELS=""
MODEL_SPECS=()
HOME_DIR="$HOME/.codex-custom"
APP_NAME=""
PORT="8787"
INTERACTIVE="1"
VERIFY_MODEL="0"
LAUNCH_APP="0"
KEYCHAIN_SERVICE="codex-custom-models-api-key"

usage() {
  cat <<'EOF'
Usage: ./install.sh [options]

  --provider openrouter|ollama
  --model 'provider/model-id[|Display Name]'   repeat up to six times
  --models /path/to/models.json
  --home /path/to/isolated/CODEX_HOME
  --app-name 'ChatGPT OpenRouter Models'
  --port 8787
  --verify                  run a real marker turn (may incur provider cost)
  --launch                  launch the verified duplicate
  --non-interactive         fail instead of asking for missing choices/login
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --provider) PROVIDER="$2"; shift 2 ;;
    --model) MODEL_SPECS+=("$2"); shift 2 ;;
    --models) MODELS="$2"; shift 2 ;;
    --home) HOME_DIR="$2"; shift 2 ;;
    --app-name) APP_NAME="$2"; shift 2 ;;
    --port) PORT="$2"; shift 2 ;;
    --keychain-service) KEYCHAIN_SERVICE="$2"; shift 2 ;;
    --verify) VERIFY_MODEL="1"; shift ;;
    --launch) LAUNCH_APP="1"; shift ;;
    --non-interactive) INTERACTIVE="0"; shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ "$PORT" =~ ^[0-9]+$ ]] && (( PORT >= 1024 && PORT <= 65535 )) || {
  echo "--port must be an integer from 1024 to 65535." >&2
  exit 2
}
[[ "$KEYCHAIN_SERVICE" =~ ^[[:alnum:]._-]+$ ]] || { echo "Invalid --keychain-service." >&2; exit 2; }
[[ "$HOME_DIR" != *['&<>"']* && "$HOME_DIR" != *$'\n'* ]] || {
  echo "--home contains characters that cannot be represented safely in the launch agent." >&2
  exit 2
}
[[ "$HOME_DIR" == /* ]] || { echo "--home must be an absolute path." >&2; exit 2; }

[[ "$(uname)" == "Darwin" ]] || {
  echo "macOS installer. Windows/Linux: see docs/INSTALL-WINDOWS-LINUX.md." >&2
  exit 1
}
NODE_BIN="$(command -v node || true)"
[[ -n "$NODE_BIN" ]] || { echo "Node.js 18 or newer is required: brew install node" >&2; exit 1; }
NODE_MAJOR="$($NODE_BIN -p 'Number(process.versions.node.split(".")[0])')"
(( NODE_MAJOR >= 18 )) || { echo "Node.js 18 or newer is required; found $($NODE_BIN --version)." >&2; exit 1; }

SOURCE_OVERRIDE="${CCM_SOURCE_APP:-${CCM_CODEX_APP:-}}"
APPLICATIONS_DIR="${CCM_APPLICATIONS_DIR:-/Applications}"
if [[ -n "$SOURCE_OVERRIDE" ]]; then
  SOURCE_APP="$(python3 "$REPO_DIR/scripts/app_bundle.py" inspect "$SOURCE_OVERRIDE" --field path)"
else
  SOURCE_APP="$(python3 "$REPO_DIR/scripts/app_bundle.py" detect --applications-dir "$APPLICATIONS_DIR" --field path)"
fi
SOURCE_NAME="$(python3 "$REPO_DIR/scripts/app_bundle.py" inspect "$SOURCE_APP" --field display_name)"
SOURCE_VERSION="$(python3 "$REPO_DIR/scripts/app_bundle.py" inspect "$SOURCE_APP" --field version)"
SOURCE_EXECUTABLE="$(python3 "$REPO_DIR/scripts/app_bundle.py" inspect "$SOURCE_APP" --field executable)"
CODEX_BIN="$(command -v codex || true)"
[[ -n "$CODEX_BIN" ]] || CODEX_BIN="$SOURCE_APP/Contents/Resources/codex"
[[ -x "$CODEX_BIN" ]] || { echo "Codex CLI not found globally or inside $SOURCE_APP." >&2; exit 1; }

ask() {
  local answer
  if [[ "$INTERACTIVE" == "0" ]]; then printf '%s' "$2"; return; fi
  read -r -p "$1 [$2]: " answer
  printf '%s' "${answer:-$2}"
}

[[ -z "$PROVIDER" ]] && PROVIDER="$(ask 'Provider (openrouter/ollama)' openrouter)"
[[ "$PROVIDER" == "openrouter" || "$PROVIDER" == "ollama" ]] || {
  echo "Provider must be openrouter or ollama." >&2
  exit 2
}
if [[ -z "$APP_NAME" ]]; then
  if [[ "$PROVIDER" == "openrouter" ]]; then APP_NAME="${SOURCE_NAME} OpenRouter Models"
  else APP_NAME="${SOURCE_NAME} Ollama Models"
  fi
fi
[[ "$APP_NAME" =~ ^[[:alnum:]][[:alnum:]\ ._-]*$ ]] || { echo "Invalid --app-name." >&2; exit 2; }
if [[ ${#MODEL_SPECS[@]} -gt 0 && "$PROVIDER" != "openrouter" ]]; then
  echo "--model catalog resolution is currently for OpenRouter; use --models for Ollama." >&2
  exit 2
fi

MODELS_DIR="$HOME_DIR/custom-models"
mkdir -p "$MODELS_DIR"
if [[ ${#MODEL_SPECS[@]} -gt 0 ]]; then
  RESOLVE_ARGS=(--out "$MODELS_DIR/models.json")
  for model in "${MODEL_SPECS[@]}"; do RESOLVE_ARGS+=(--model "$model"); done
  "$NODE_BIN" "$REPO_DIR/scripts/resolve-models.mjs" "${RESOLVE_ARGS[@]}"
else
  if [[ -z "$MODELS" ]]; then MODELS="$REPO_DIR/examples/models.${PROVIDER}.json"; fi
  [[ -f "$MODELS" ]] || MODELS="$REPO_DIR/examples/models.json"
  [[ -f "$MODELS" ]] || { echo "Models file not found: $MODELS" >&2; exit 1; }
  cp "$MODELS" "$MODELS_DIR/models.json"
  chmod 600 "$MODELS_DIR/models.json"
fi
"$NODE_BIN" "$REPO_DIR/scripts/render-catalog.mjs" "$MODELS_DIR/models.json" "$MODELS_DIR/catalog.json"
cp "$REPO_DIR/src/proxy.mjs" "$MODELS_DIR/proxy.mjs"
DEFAULT_SLUG="$($NODE_BIN -e 'const m=require(process.argv[1]);const l=Array.isArray(m)?m:m.models;process.stdout.write((l[0]&&l[0].slug)||"gpt-5.5")' "$MODELS_DIR/models.json")"

NEEDS_KEY="1"
UPSTREAM="https://openrouter.ai/api/v1"
if [[ "$PROVIDER" == "ollama" ]]; then
  NEEDS_KEY="0"
  UPSTREAM="http://localhost:11434/v1"
elif ! security find-generic-password -a "$USER" -s "$KEYCHAIN_SERVICE" >/dev/null 2>&1; then
  if [[ "$INTERACTIVE" == "0" ]]; then
    echo "OpenRouter authorization is required. Run: node scripts/openrouter-login.mjs" >&2
    exit 3
  fi
  "$NODE_BIN" "$REPO_DIR/scripts/openrouter-login.mjs" --account "$USER" --service "$KEYCHAIN_SERVICE"
fi

sed -e "s|__DEFAULT_SLUG__|${DEFAULT_SLUG}|g" -e "s|__MODELS_DIR__|${MODELS_DIR}|g" -e "s|__PROXY_PORT__|${PORT}|g" \
  "$REPO_DIR/templates/config.isolated-home.toml.tmpl" > "$HOME_DIR/config.toml"
chmod 600 "$HOME_DIR/config.toml"

PLIST="$HOME/Library/LaunchAgents/com.codexcustommodels.proxy.${PORT}.plist"
LABEL="com.codexcustommodels.proxy.${PORT}"
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>${LABEL}</string>
  <key>ProgramArguments</key><array>
    <string>${NODE_BIN}</string><string>${MODELS_DIR}/proxy.mjs</string>
  </array>
  <key>EnvironmentVariables</key><dict>
    <key>CCM_PROXY_PORT</key><string>${PORT}</string>
    <key>CCM_MODELS_JSON</key><string>${MODELS_DIR}/models.json</string>
    <key>CCM_UPSTREAM</key><string>${UPSTREAM}</string>
    <key>CCM_NEEDS_KEY</key><string>${NEEDS_KEY}</string>
    <key>CCM_KEYCHAIN_SERVICE</key><string>${KEYCHAIN_SERVICE}</string>
    <key>CCM_KEYCHAIN_ACCOUNT</key><string>${USER}</string>
    <key>CCM_TITLE</key><string>${APP_NAME}</string>
    <key>CCM_HTTP_REFERER</key><string>https://github.com/lennoxsaint/codex-custom-models</string>
    <key>CCM_PROXY_LOG</key><string>${HOME_DIR}/proxy.log</string>
  </dict>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>${HOME_DIR}/proxy.stdout.log</string>
  <key>StandardErrorPath</key><string>${HOME_DIR}/proxy.stderr.log</string>
</dict></plist>
PLIST
plutil -lint "$PLIST" >/dev/null
launchctl bootout "gui/$(id -u)" "$PLIST" >/dev/null 2>&1 || launchctl bootout "gui/$(id -u)/${LABEL}" >/dev/null 2>&1 || true
for _ in {1..20}; do
  launchctl print "gui/$(id -u)/${LABEL}" >/dev/null 2>&1 || break
  sleep 0.1
done
BOOTSTRAPPED="0"
for _ in {1..10}; do
  if launchctl bootstrap "gui/$(id -u)" "$PLIST" >/dev/null 2>&1; then BOOTSTRAPPED="1"; break; fi
  launchctl print "gui/$(id -u)/${LABEL}" >/dev/null 2>&1 && { BOOTSTRAPPED="1"; break; }
  sleep 0.2
done
[[ "$BOOTSTRAPPED" == "1" ]] || { echo "Could not register launch agent $LABEL." >&2; exit 1; }
for _ in {1..80}; do
  curl -fsS "http://127.0.0.1:${PORT}/health" >/dev/null 2>&1 && break
  sleep 0.1
done
curl -fsS "http://127.0.0.1:${PORT}/health" >/dev/null 2>&1 || {
  echo "Proxy failed to start; inspect $HOME_DIR/proxy.stderr.log" >&2
  exit 1
}

CCM_SOURCE_APP="$SOURCE_APP" CCM_APPLICATIONS_DIR="$APPLICATIONS_DIR" \
  bash "$REPO_DIR/scripts/duplicate-codex-app.sh" "$APP_NAME" "$HOME_DIR"

VERIFY_ARGS=(--app-name "$APP_NAME" --home "$HOME_DIR" --port "$PORT" --codex-bin "$CODEX_BIN")
[[ "$VERIFY_MODEL" == "1" ]] || VERIFY_ARGS+=(--skip-marker)
bash "$REPO_DIR/scripts/verify.sh" "${VERIFY_ARGS[@]}"

python3 - "$HOME_DIR/install-receipt.json" "$SOURCE_APP" "$SOURCE_VERSION" "$SOURCE_EXECUTABLE" "$APP_NAME" "$APPLICATIONS_DIR" "$HOME_DIR" "$PROVIDER" "$PORT" <<'PY'
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

out, source, version, executable, app_name, applications, home, provider, port = sys.argv[1:]
payload = {
    "schema": "codex-custom-models-install-v3",
    "installed_at": datetime.now(timezone.utc).isoformat(),
    "source_app": source,
    "source_version": version,
    "source_executable": executable,
    "installed_app": str(Path(applications) / f"{app_name}.app"),
    "codex_home": home,
    "provider": provider,
    "proxy_port": int(port),
    "credential_location": "macOS Keychain" if provider == "openrouter" else "not required",
}
Path(out).write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
PY
chmod 600 "$HOME_DIR/install-receipt.json"

if [[ "$LAUNCH_APP" == "1" ]]; then
  open "$APPLICATIONS_DIR/${APP_NAME}.app"
  APP_PROCESS_PATTERN="${APPLICATIONS_DIR}/${APP_NAME}.app/Contents/MacOS/${SOURCE_EXECUTABLE}.real"
  for _ in {1..40}; do
    pgrep -f "$APP_PROCESS_PATTERN" >/dev/null 2>&1 && break
    sleep 0.25
  done
  sleep 2
  APP_PID="$(pgrep -f "$APP_PROCESS_PATTERN" | head -1 || true)"
  [[ -n "$APP_PID" ]] || { echo "The copied app did not remain running after launch." >&2; exit 1; }
  echo "Desktop launch: PASS (pid $APP_PID, isolated copied executable)"
fi

echo
echo "Setup complete: ${APPLICATIONS_DIR}/${APP_NAME}.app"
echo "Source verified: $SOURCE_APP ($SOURCE_NAME $SOURCE_VERSION)"
echo "Models: $(curl -fsS "http://127.0.0.1:${PORT}/v1/models" | "$NODE_BIN" -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const j=JSON.parse(s);process.stdout.write((j.data||[]).map(m=>m.name).join(", "))})')"
echo "OpenRouter usage is billed to the member's own account; this tool does not provide free access."
