#!/usr/bin/env bash
# Machine-readable preflight for agents before installation.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APPLICATIONS_DIR="${CCM_APPLICATIONS_DIR:-/Applications}"
SOURCE_OVERRIDE="${CCM_SOURCE_APP:-${CCM_CODEX_APP:-}}"

[[ "$(uname)" == "Darwin" ]] || { echo '{"status":"blocked","blocker":"macOS_required"}'; exit 1; }
NODE_BIN="$(command -v node || true)"
[[ -n "$NODE_BIN" ]] || { echo '{"status":"blocked","blocker":"node_18_required"}'; exit 1; }
NODE_MAJOR="$($NODE_BIN -p 'Number(process.versions.node.split(".")[0])')"
(( NODE_MAJOR >= 18 )) || { echo '{"status":"blocked","blocker":"node_18_required"}'; exit 1; }
command -v clang >/dev/null || { echo '{"status":"blocked","blocker":"xcode_command_line_tools_required"}'; exit 1; }

if [[ -n "$SOURCE_OVERRIDE" ]]; then
  SOURCE_JSON="$(python3 "$REPO_DIR/scripts/app_bundle.py" inspect "$SOURCE_OVERRIDE")"
else
  SOURCE_JSON="$(python3 "$REPO_DIR/scripts/app_bundle.py" detect --applications-dir "$APPLICATIONS_DIR")"
fi
SOURCE_PATH="$(printf '%s' "$SOURCE_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin)["path"])')"
codesign --verify --deep --strict "$SOURCE_PATH" >/dev/null 2>&1 || {
  echo '{"status":"blocked","blocker":"official_source_signature_invalid"}'
  exit 1
}
TEAM_ID="$(codesign -dv --verbose=4 "$SOURCE_PATH" 2>&1 | awk -F= '/^TeamIdentifier=/{print $2; exit}')"
[[ "$TEAM_ID" == "2DC432GLL2" ]] || {
  echo '{"status":"blocked","blocker":"official_source_team_mismatch"}'
  exit 1
}

KEY_STATUS="missing"
security find-generic-password -a "$USER" -s codex-custom-models-api-key >/dev/null 2>&1 && KEY_STATUS="present"
printf '%s' "$SOURCE_JSON" | python3 -c 'import json,sys; p=json.load(sys.stdin); p.update(status="ready", node_version=sys.argv[1], openrouter_credential=sys.argv[2]); print(json.dumps(p, sort_keys=True))' "$($NODE_BIN --version)" "$KEY_STATUS"
