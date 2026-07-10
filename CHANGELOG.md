# Changelog

## v3 — unified ChatGPT desktop app + one-link agent setup
- Supports OpenAI's July 9, 2026 unified `/Applications/ChatGPT.app` while retaining legacy `Codex.app` fallback. Source name, version, and executable are detected from `Info.plist` instead of hard-coded.
- Verifies the official source bundle ID, OpenAI signing team, and signature before copying; verifies the untouched source again after an atomic managed install.
- Defaults to `ChatGPT OpenRouter Models.app`, with an isolated `CODEX_HOME`, unique user-owned bundle ID, strict structural verification, and an install receipt.
- Isolates the unified app's Electron singleton/profile through `CODEX_ELECTRON_USER_DATA_PATH`, preventing launches from being handed back to the official ChatGPT process.
- Passes the same isolated profile as Chromium's early `--user-data-dir` argument through a tiny bundle-local native launcher, before Electron's single-instance lock runs.
- Adds official OpenRouter OAuth PKCE browser authorization. Credentials go directly to macOS Keychain and are never pasted into an agent conversation.
- Adds repeatable `--model 'provider/id|Display Name'` flags backed by OpenRouter's live catalog and real context windows.
- Adds `AGENTS.md`, machine-readable preflight, strict marker verification, agent-first docs, Python/Node regression tests, and CI coverage for modern/legacy bundle detection.
- Clarifies that custom models power the Codex workspace inside the unified app, not Chat or Work.

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
