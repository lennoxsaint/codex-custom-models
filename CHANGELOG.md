# Changelog

## v2.1 — survive Codex updates (no "improperly signed" error)
- **Fixes the `Update Error! The update is improperly signed and could not be validated`
  dialog.** Codex auto-updates via Sparkle; in an ad-hoc re-signed fork the update can never
  validate against the copy's signature (Sparkle error 4005 / EdDSA 3002), and a successful
  update would overwrite the fork anyway. `scripts/duplicate-codex-app.sh` now neutralizes the
  fork's updater by removing the native `sparkle.node` addon (Codex's own "updater unavailable"
  path → no checks, no dialog) plus belt-and-braces Sparkle Info.plist keys
  (`SUEnableAutomaticChecks=false`, `SUScheduledCheckInterval=0`, `SUAutomaticallyUpdate=false`).
- **New `update.sh`:** updating = re-fork from your real Codex.app (which updates itself normally
  with its valid OpenAI signature), preserving app name + CODEX_HOME (models/config/proxy live in
  CODEX_HOME and are untouched). Verified re-forking 26.616.71553 → 26.616.81150.
- Tested on Codex 26.616.71553 and 26.616.81150.

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
