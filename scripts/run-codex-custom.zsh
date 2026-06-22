#!/bin/zsh
# Generalized launcher for the "Codex Custom Models" instance.
# Starts the local alias proxy (if needed) and opens an ISOLATED Codex Desktop
# instance with its own CODEX_HOME + Electron user-data dir, so it never
# disturbs your normal Codex. Safe to re-run.
set -euo pipefail

CODEX_HOME="${CCM_HOME:-$HOME/.codex-custom}"
MODELS_DIR="${CODEX_HOME}/custom-models"
PROXY_SCRIPT="${MODELS_DIR}/proxy.mjs"
MODELS_JSON="${MODELS_DIR}/models.json"
PROXY_PORT="${CCM_PROXY_PORT:-8787}"
PROXY_LABEL="com.codexcustommodels.proxy"
PROXY_LOG="${CODEX_HOME}/proxy.log"
PROXY_STDOUT="${CODEX_HOME}/proxy.stdout.log"
PROXY_STDERR="${CODEX_HOME}/proxy.stderr.log"
USER_DATA_DIR="${CODEX_HOME}/electron-user-data"
WORKSPACE="${CCM_WORKSPACE:-$HOME/Codex Custom Models Workspace}"
CODEX_APP="${CCM_CODEX_APP:-/Applications/Codex.app}"
NEEDS_KEY="${CCM_NEEDS_KEY:-1}"
UPSTREAM="${CCM_UPSTREAM:-https://openrouter.ai/api/v1}"
NODE_BIN="${CCM_NODE_BIN:-$(command -v node)}"

mkdir -p "${CODEX_HOME}" "${MODELS_DIR}" "${USER_DATA_DIR}" "${WORKSPACE}"

proxy_health_ok() { curl -fsS "http://127.0.0.1:${PROXY_PORT}/health" >/dev/null 2>&1; }

start_proxy() {
  if proxy_health_ok; then return 0; fi
  if lsof -nP -iTCP:"${PROXY_PORT}" -sTCP:LISTEN >/dev/null 2>&1; then
    print -r -- "Port ${PROXY_PORT} is in use by another process. Set CCM_PROXY_PORT to a free port." >&2
    return 1
  fi
  launchctl remove "${PROXY_LABEL}" >/dev/null 2>&1 || true
  launchctl submit -l "${PROXY_LABEL}" -o "${PROXY_STDOUT}" -e "${PROXY_STDERR}" -- \
    /usr/bin/env \
    "CCM_PROXY_PORT=${PROXY_PORT}" \
    "CCM_PROXY_LOG=${PROXY_LOG}" \
    "CCM_MODELS_JSON=${MODELS_JSON}" \
    "CCM_UPSTREAM=${UPSTREAM}" \
    "CCM_NEEDS_KEY=${NEEDS_KEY}" \
    "${NODE_BIN}" "${PROXY_SCRIPT}"
  for _ in {1..80}; do proxy_health_ok && return 0; sleep 0.1; done
  print -r -- "Proxy failed to start. See ${PROXY_STDERR}" >&2
  return 1
}

start_proxy

if [[ "${CCM_CONFIG_ONLY:-0}" == "1" ]]; then
  print -r -- "Configured + proxy healthy on 127.0.0.1:${PROXY_PORT}"
  exit 0
fi

if [[ ! -d "${CODEX_APP}" ]]; then
  print -r -- "Codex.app not found; CLI is ready: CODEX_HOME=${CODEX_HOME} codex" >&2
  exit 0
fi

/usr/bin/open -n "${CODEX_APP}" \
  --env "CODEX_HOME=${CODEX_HOME}" \
  --env "CODEX_ELECTRON_USER_DATA_PATH=${USER_DATA_DIR}" \
  --args "--user-data-dir=${USER_DATA_DIR}" "${WORKSPACE}"
