#!/usr/bin/env bash
# codex-custom-models — macOS HERO installer.
# Builds a second, isolated Codex instance with custom models (OpenRouter or local Ollama),
# a local alias proxy, a catalog the Desktop picker can switch, and a renamed .app wrapper.
# SAFE defaults. Never ships a key or a vendor icon. Idempotent.
#
# Flags (all optional; interactive by default):
#   --provider openrouter|ollama
#   --models <path>         models.json (default: examples/models.json)
#   --home <dir>            isolated CODEX_HOME (default: ~/.codex-custom)
#   --app-name <name>       (default: "Codex Custom Models")
#   --port <n>              proxy port (default: 8787)
#   --no-app                skip building the .app (config + proxy only)
#   --non-interactive       no prompts (for testing / CI)
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROVIDER=""; MODELS=""; HOME_DIR="$HOME/.codex-custom"; APP_NAME="Codex Custom Models"
PORT="8787"; NO_APP="0"; INTERACTIVE="1"
while [[ $# -gt 0 ]]; do case "$1" in
  --provider) PROVIDER="$2"; shift 2;;
  --models) MODELS="$2"; shift 2;;
  --home) HOME_DIR="$2"; shift 2;;
  --app-name) APP_NAME="$2"; shift 2;;
  --port) PORT="$2"; shift 2;;
  --no-app) NO_APP="1"; shift;;
  --non-interactive) INTERACTIVE="0"; shift;;
  *) echo "unknown flag: $1"; exit 2;;
esac; done

[[ "$(uname)" == "Darwin" ]] || { echo "This is the macOS installer. On Windows/Linux see docs/INSTALL-WINDOWS-LINUX.md."; exit 1; }
command -v codex >/dev/null 2>&1 || { echo "Codex CLI not found. Install Codex first: https://developers.openai.com/codex"; exit 1; }
NODE_BIN="$(command -v node)"; [[ -n "$NODE_BIN" ]] || { echo "Node.js (>=18) required: brew install node"; exit 1; }

ask() { local p="$1" d="$2" a; if [[ "$INTERACTIVE" == "0" ]]; then echo "$d"; else read -r -p "$p [$d]: " a; echo "${a:-$d}"; fi; }

[[ -z "$PROVIDER" ]] && PROVIDER="$(ask 'Provider (openrouter/ollama)' 'openrouter')"
[[ -z "$MODELS" ]] && MODELS="$REPO_DIR/examples/models.${PROVIDER}.json"
[[ -f "$MODELS" ]] || MODELS="$REPO_DIR/examples/models.json"
[[ -f "$MODELS" ]] || { echo "models file not found: $MODELS"; exit 1; }

MODELS_DIR="$HOME_DIR/custom-models"
mkdir -p "$MODELS_DIR" "$HOME_DIR/electron-user-data"

# --- models.json -> install dir, render Codex picker catalog.json, copy proxy ---
cp "$MODELS" "$MODELS_DIR/models.json"
node "$REPO_DIR/scripts/render-catalog.mjs" "$MODELS_DIR/models.json" "$MODELS_DIR/catalog.json"
cp "$REPO_DIR/src/proxy.mjs" "$MODELS_DIR/proxy.mjs"

DEFAULT_SLUG="$(node -e 'const m=require(process.argv[1]);const l=Array.isArray(m)?m:m.models;process.stdout.write((l[0]&&l[0].slug)||"gpt-5.5")' "$MODELS_DIR/models.json")"

NEEDS_KEY="1"; UPSTREAM="https://openrouter.ai/api/v1"
if [[ "$PROVIDER" == "ollama" ]]; then NEEDS_KEY="0"; UPSTREAM="http://localhost:11434/v1"; fi

# --- key handling (OpenRouter only): stdin -> Keychain, never a CLI arg / file / log ---
if [[ "$PROVIDER" == "openrouter" ]]; then
  if security find-generic-password -a "$USER" -s codex-custom-models-api-key -w >/dev/null 2>&1; then
    echo "OpenRouter key already in Keychain (reusing)."
  elif [[ "$INTERACTIVE" == "0" ]]; then
    echo "WARN: no OpenRouter key in Keychain; set OPENROUTER_API_KEY or add it before launch."
  else
    printf "Paste your OpenRouter API key (input hidden): "
    read -r -s OR_KEY; echo
    # -w with no value reads the secret from STDIN -> stays out of shell history / argv
    printf '%s' "$OR_KEY" | security add-generic-password -a "$USER" -s codex-custom-models-api-key -U -w >/dev/null
    unset OR_KEY
    echo "Stored in Keychain service 'codex-custom-models-api-key'."
  fi
fi

# --- render isolated config (SAFE defaults) ---
sed -e "s|__DEFAULT_SLUG__|${DEFAULT_SLUG}|g" \
    -e "s|__MODELS_DIR__|${MODELS_DIR}|g" \
    -e "s|__PROXY_PORT__|${PORT}|g" \
    "$REPO_DIR/templates/config.isolated-home.toml.tmpl" > "$HOME_DIR/config.toml"
chmod 600 "$HOME_DIR/config.toml"

# --- install the run script ---
RUN_SCRIPT="$MODELS_DIR/run-codex-custom.zsh"
cp "$REPO_DIR/scripts/run-codex-custom.zsh" "$RUN_SCRIPT"; chmod +x "$RUN_SCRIPT"

# --- build the .app (unless --no-app) ---
if [[ "$NO_APP" == "0" ]]; then
  APP_EXEC="$(echo "$APP_NAME" | tr ' ' '-')"
  BUNDLE_ID="com.$(echo "$USER" | tr -cd '[:alnum:]').codexcustommodels"
  APP="/Applications/${APP_NAME}.app"
  mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
  sed -e "s|__APP_NAME__|${APP_NAME}|g" -e "s|__APP_EXEC__|${APP_EXEC}|g" -e "s|__BUNDLE_ID__|${BUNDLE_ID}|g" \
      "$REPO_DIR/templates/Info.plist.tmpl" > "$APP/Contents/Info.plist"
  sed -e "s|__RUN_SCRIPT__|${RUN_SCRIPT}|g" \
      "$REPO_DIR/templates/app-launcher.zsh.tmpl" > "$APP/Contents/MacOS/${APP_EXEC}"
  chmod +x "$APP/Contents/MacOS/${APP_EXEC}"
  CCM_REPO_DIR="$REPO_DIR" bash "$REPO_DIR/scripts/source-icon.sh" "$APP/Contents/Resources/AppIcon.icns" || true
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP" || true
  echo "Built app: $APP"
fi

# --- start proxy + verify ---
CCM_HOME="$HOME_DIR" CCM_PROXY_PORT="$PORT" CCM_NEEDS_KEY="$NEEDS_KEY" CCM_UPSTREAM="$UPSTREAM" \
  CCM_CONFIG_ONLY=1 CCM_NODE_BIN="$NODE_BIN" "$RUN_SCRIPT"
CCM_HOME="$HOME_DIR" CCM_PROXY_PORT="$PORT" bash "$REPO_DIR/scripts/verify.sh" "$DEFAULT_SLUG" || true

echo
echo "Done. To launch: open the '${APP_NAME}' app and drag it to your Dock."
echo "CLI: CODEX_HOME=${HOME_DIR} codex --profile custom"
echo "This runs an AI agent on your machine. Review commands before approving."
echo "It does NOT give you free AI — you pay your own OpenRouter usage (Ollama is local/free). See README."
