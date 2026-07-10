# How it works

## July 2026 app identity

OpenAI's unified desktop application is installed as `/Applications/ChatGPT.app`, displays `ChatGPT`, executes `Contents/MacOS/ChatGPT`, and retains the Codex bundle identifier `com.openai.codex`. Older installations used `/Applications/Codex.app` and executable `Codex`.

`scripts/app_bundle.py` treats those as two generations of the same supported source contract. The modern app wins when both are present.

## Local duplication

`scripts/duplicate-codex-app.sh`:

1. Verifies the source bundle structure, OpenAI bundle ID, code signature, and team ID.
2. Copies it into a staging bundle under `/Applications`.
3. Gives the copy a user-owned bundle ID and display name.
4. injects an isolated `CODEX_HOME` and `CODEX_ELECTRON_USER_DATA_PATH` without deleting unrelated source environment keys.
5. compiles a tiny native launcher so Chromium receives `--user-data-dir` before singleton detection; the copied real executable remains inside the same bundle.
6. Applies the standard-title-bar compatibility patch when the known byte-preserving pattern exists.
7. Disables Sparkle only in the copy, ad-hoc signs it, verifies it, and atomically installs it.
8. Verifies the official source again.

The source app is never changed. The repository contains no vendor binary or icon.

## Model routing

Codex Desktop reads the generated model catalog from the isolated home. Picker-safe aliases such as `gpt-5.5` map to user-selected OpenRouter IDs in `models.json`.

The launch agent runs `src/proxy.mjs` on `127.0.0.1`. For each Codex request it:

- reads the OpenRouter credential from Keychain,
- rewrites only the configured model alias,
- removes fields the selected upstream rejects,
- streams the response back,
- records metadata without prompt or completion contents.

Ollama uses the same local routing shape without a credential.

## Authentication

`scripts/openrouter-login.mjs` creates a random PKCE verifier, opens OpenRouter's official authorization page, receives the redirect on a temporary localhost port, exchanges the one-time code, and writes the returned credential to Keychain through stdin. The key is never printed or put in command arguments.

## Proof levels

- `scripts/preflight.sh`: official source and dependency readiness.
- `scripts/verify.sh --skip-marker`: app signature/config, proxy identity, and catalog structure.
- `scripts/verify.sh`: all structural checks plus a real marker response and proxy receipt.
- Visual/Dock verification: proves the correct app launched; it does not replace the marker turn.

Because the duplicate has a new ad-hoc signature, macOS may request first-launch access to the official app's encrypted-storage key or protected folders. Those prompts are OS security boundaries, not installer failures, and the agent must not bypass them silently.
