#!/usr/bin/env bash
# Health + model-list + marker turn through the proxy.
set -uo pipefail
SLUG="${1:-gpt-5.5}"
PORT="${CCM_PROXY_PORT:-8787}"
HOME_DIR="${CCM_HOME:-$HOME/.codex-custom}"
echo "== /health =="
curl -fsS "http://127.0.0.1:${PORT}/health" && echo || { echo "FAIL: proxy not healthy on :${PORT}"; exit 1; }
echo "== /v1/models =="
curl -fsS "http://127.0.0.1:${PORT}/v1/models" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const j=JSON.parse(s);console.log((j.data||[]).map(m=>m.id+" -> "+m.target_model).join("\n"))})' || echo "(model list parse skipped)"
echo "== marker turn (CODEX_HOME=${HOME_DIR}) =="
OUT="$(CODEX_HOME="$HOME_DIR" codex exec --model "$SLUG" "Reply with exactly: OK-CUSTOM-MODELS" 2>&1 || true)"
echo "$OUT" | tail -5
echo "$OUT" | grep -q "OK-CUSTOM-MODELS" && echo "MARKER: PASS" || echo "MARKER: not confirmed (check key / model id / network)"
