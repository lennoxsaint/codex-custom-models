#!/usr/bin/env bash
# codex-custom-models — macOS installer (separate-bundle approach).
#
# Builds a genuinely separate "Codex Custom Models.app" (its own bundle ID, ad-hoc
# re-signed) that runs your chosen models (OpenRouter via a local alias proxy, or
# local Ollama). This is the approach that has WORKING window controls — a 2nd
# instance of the same Codex bundle (the old `open -n` trick) leaves the traffic-
# lights dead. SAFE defaults. Never ships a key or a vendor binary (copies YOUR
# local Codex.app). Tested on Codex 26.616.71553.
#
# Flags: --provider openrouter|ollama  --models <file>  --home <dir>
#        --app-name "<name>"  --port <n>  --non-interactive
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROVIDER=""; MODELS=""; HOME_DIR="$HOME/.codex-custom"; APP_NAME="Codex Custom Models"
PORT="8787"; INTERACTIVE="1"
while [[ $# -gt 0 ]]; do case "$1" in
  --provider) PROVIDER="$2"; shift 2;;
  --models) MODELS="$2"; shift 2;;
  --home) HOME_DIR="$2"; shift 2;;
  --app-name) APP_NAME="$2"; shift 2;;
  --port) PORT="$2"; shift 2;;
  --non-interactive) INTERACTIVE="0"; shift;;
  *) echo "unknown flag: $1"; exit 2;;
esac; done

[[ "$(uname)" == "Darwin" ]] || { echo "macOS installer. Windows/Linux: docs/INSTALL-WINDOWS-LINUX.md"; exit 1; }
command -v codex >/dev/null || { echo "Install Codex first: https://developers.openai.com/codex"; exit 1; }
[[ -d /Applications/Codex.app ]] || { echo "/Applications/Codex.app not found — install the Codex desktop app first."; exit 1; }
NODE_BIN="$(command -v node)"; [[ -n "$NODE_BIN" ]] || { echo "Node.js >=18 required (brew install node)."; exit 1; }

ask(){ local a; if [[ "$INTERACTIVE" == 0 ]]; then echo "$2"; else read -r -p "$1 [$2]: " a; echo "${a:-$2}"; fi; }
[[ -z "$PROVIDER" ]] && PROVIDER="$(ask 'Provider (openrouter/ollama)' openrouter)"
[[ -z "$MODELS" ]] && MODELS="$REPO_DIR/examples/models.${PROVIDER}.json"
[[ -f "$MODELS" ]] || MODELS="$REPO_DIR/examples/models.json"

MODELS_DIR="$HOME_DIR/custom-models"; mkdir -p "$MODELS_DIR"
cp "$MODELS" "$MODELS_DIR/models.json"
node "$REPO_DIR/scripts/render-catalog.mjs" "$MODELS_DIR/models.json" "$MODELS_DIR/catalog.json"
cp "$REPO_DIR/src/proxy.mjs" "$MODELS_DIR/proxy.mjs"
DEFAULT_SLUG="$(node -e 'const m=require(process.argv[1]);const l=Array.isArray(m)?m:m.models;process.stdout.write((l[0]&&l[0].slug)||"gpt-5.5")' "$MODELS_DIR/models.json")"
NEEDS_KEY="1"; UPSTREAM="https://openrouter.ai/api/v1"
[[ "$PROVIDER" == ollama ]] && { NEEDS_KEY="0"; UPSTREAM="http://localhost:11434/v1"; }

# --- OpenRouter key -> Keychain via stdin (never argv / file / log) ---
if [[ "$PROVIDER" == openrouter ]]; then
  if security find-generic-password -a "$USER" -s codex-custom-models-api-key -w >/dev/null 2>&1; then
    echo "OpenRouter key already in Keychain (reusing)."
  elif [[ "$INTERACTIVE" == 1 ]]; then
    printf "Paste your OpenRouter API key (hidden): "; read -r -s K; echo
    printf '%s' "$K" | security add-generic-password -a "$USER" -s codex-custom-models-api-key -U -w >/dev/null; unset K
    echo "Stored in Keychain (codex-custom-models-api-key)."
  fi
fi

# --- isolated config (SAFE defaults) ---
sed -e "s|__DEFAULT_SLUG__|${DEFAULT_SLUG}|g" -e "s|__MODELS_DIR__|${MODELS_DIR}|g" -e "s|__PROXY_PORT__|${PORT}|g" \
    "$REPO_DIR/templates/config.isolated-home.toml.tmpl" > "$HOME_DIR/config.toml"
chmod 600 "$HOME_DIR/config.toml"

# --- proxy as a launchd agent (so the standalone app always has it up) ---
if [[ "$PROVIDER" == openrouter ]]; then
  PLIST="$HOME/Library/LaunchAgents/com.codexcustommodels.proxy.plist"
  mkdir -p "$HOME/Library/LaunchAgents"
  cat > "$PLIST" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.codexcustommodels.proxy</string>
  <key>ProgramArguments</key><array>
    <string>${NODE_BIN}</string><string>${MODELS_DIR}/proxy.mjs</string>
  </array>
  <key>EnvironmentVariables</key><dict>
    <key>CCM_PROXY_PORT</key><string>${PORT}</string>
    <key>CCM_MODELS_JSON</key><string>${MODELS_DIR}/models.json</string>
    <key>CCM_UPSTREAM</key><string>${UPSTREAM}</string>
    <key>CCM_NEEDS_KEY</key><string>${NEEDS_KEY}</string>
    <key>CCM_PROXY_LOG</key><string>${HOME_DIR}/proxy.log</string>
  </dict>
  <key>RunAtLoad</key><true/><key>KeepAlive</key><true/>
  <key>StandardErrorPath</key><string>${HOME_DIR}/proxy.stderr.log</string>
</dict></plist>
PL
  launchctl unload "$PLIST" 2>/dev/null || true
  launchctl load "$PLIST"
  for _ in {1..40}; do curl -fsS "http://127.0.0.1:${PORT}/health" >/dev/null 2>&1 && break; sleep 0.1; done
  curl -fsS "http://127.0.0.1:${PORT}/health" >/dev/null 2>&1 && echo "proxy up on 127.0.0.1:${PORT}" || echo "WARN: proxy not healthy yet (check ${HOME_DIR}/proxy.stderr.log)"
fi

# --- build the SEPARATE-BUNDLE app (the actual window-controls fix) ---
bash "$REPO_DIR/scripts/duplicate-codex-app.sh" "$APP_NAME" "$HOME_DIR"

echo
echo "Done. Open '${APP_NAME}' from /Applications and drag it to your Dock."
echo "It runs an AI agent on your machine — review commands before approving."
echo "It does NOT give you free AI: OpenRouter bills your own key (Ollama is local/free). See README."
