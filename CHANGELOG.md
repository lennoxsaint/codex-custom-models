# Changelog

## v2 — separate-bundle approach (working window controls)
- **Breaking/approach change:** the duplicate is now a genuinely separate app bundle
  (`Codex Custom Models.app`, own CFBundleIdentifier, ad-hoc re-signed) built from your
  local Codex.app — replacing the old `open -n --user-data-dir` 2nd-instance wrapper.
- **Fixes dead traffic-light buttons:** same-bundle 2nd instances are conflated by macOS
  window management; a separate bundle resolves it. Primary windows are patched to the
  standard title bar (`titleBarStyle:default`) to fix the inset hit-area offset.
- Proxy now runs as a launchd agent (`com.codexcustommodels.proxy`) so the standalone app
  always has it up.
- `scripts/duplicate-codex-app.sh` added. `uninstall.sh` updated.
- Tested on Codex 26.616.71553.

## v1
- Initial: isolated CODEX_HOME + local alias proxy (OpenRouter/Ollama), safe defaults,
  copy-paste mega-prompt, cross-platform fallback. (Used the open -n wrapper — superseded.)
