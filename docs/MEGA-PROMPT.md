# The copy-paste mega-prompt

Paste everything in the box below into your own **Codex CLI** or **Claude Code**. Your agent will build a second, isolated Codex with custom models on your machine — safely and idempotently.

```text
You are my build agent. Build a "second Codex with custom models" setup on THIS machine, end to end, idempotently and safely. Do NOT redistribute any vendor assets and do NOT ship anyone else's API key. Explain what you're about to do before destructive actions, and STOP and ask me if a precondition fails.

GOAL
A SECOND, independent Codex instance that talks to custom models (OpenRouter cloud models, OR a local Ollama model) instead of the default OpenAI models — without breaking my normal Codex. On macOS also build a renamed, dockable app wrapper with an in-app model picker. On Windows/Linux a CLI profile is fine (no renamed app).

MECHANISM (not a copy of the .app):
- an ISOLATED CODEX_HOME (separate config dir) so the second instance can't corrupt my main Codex,
- a tiny LOCAL alias proxy (127.0.0.1:8787) that rewrites OpenAI-style model slugs to real provider model ids,
- a catalog file so the Desktop model picker can show + switch the custom models,
- a thin .app wrapper (macOS only) that launches that isolated instance using MY OWN locally-installed Codex icon.

STEP 0 — PRECHECKS (report results, then continue)
1. Detect OS. Print which path you'll take (macOS = HERO; Windows/Linux = FALLBACK).
2. `codex --version` — if missing, STOP: tell me to install Codex first (https://developers.openai.com/codex). Do NOT install Codex yourself.
3. macOS HERO needs Node >= 18 (`node --version`) — if missing, STOP and tell me (`brew install node`).
4. Print a one-line plan of the files you'll create and where.

STEP 1 — ASK ME (wait for answers)
Q1. Provider: "OpenRouter (cloud)" or "Ollama (local)"?
Q2. Which model(s)? OpenRouter: 1-4 model ids (e.g. z-ai/glm-4.6, moonshotai/kimi-k2, qwen/qwen3-coder, deepseek/deepseek-chat) + a short display name each. Ollama: which local models (you may run `ollama list`); confirm `ollama serve` is reachable at http://localhost:11434.

STEP 2 — SECRETS (never hardcode, never echo)
OpenRouter only: the key must NEVER be written to a file, log, or printed.
- macOS: store in Keychain under service `codex-custom-models-api-key`. Prompt me with a hidden `read -s`, then store by piping the value to `security add-generic-password -a "$USER" -s codex-custom-models-api-key -U -w` over STDIN (not as a CLI arg). Don't overwrite an existing item without asking.
- Windows/Linux: use an env var `OPENROUTER_API_KEY` referenced via `env_key` in config; presence-check only, never print.
Ollama: no key.

STEP 3a — macOS HERO (idempotent; back up any file you overwrite to <file>.bak.<timestamp> once)
A) ~/.codex-custom/config.toml:
   model = "<first slug, e.g. gpt-5.5>"; model_provider = "custom_alias_proxy"; model_catalog_json = "~/.codex-custom/custom-models/catalog.json"
   [model_providers.custom_alias_proxy] base_url = "http://127.0.0.1:8787/v1"
   SAFETY (mandatory): approval_policy = "on-request"; sandbox_mode = "workspace-write". DO NOT use "never" or "danger-full-access". No trust_level="trusted". If you find those anywhere, remove them and tell me.
B) ~/.codex-custom/custom-models/models.json: array of { slug, display_name, target, context_window }. slug = OpenAI-style alias the picker shows; target = real model id.
C) ~/.codex-custom/custom-models/catalog.json: the Codex picker catalog rendered from models.json (slug, display_name, description, visibility:"list", supported_in_api:true, context_window, input_modalities:["text"]).
D) ~/.codex-custom/custom-models/proxy.mjs (Node, no deps): build a slug->target map from models.json; read the key from Keychain at request time (Ollama: none); endpoints GET /health, GET /v1/models, POST /v1/chat/completions (+ pass-through /v1/responses); on each request rewrite body.model alias->target and STRIP body.reasoning / reasoning_effort; forward to https://openrouter.ai/api/v1 (Ollama: http://localhost:11434/v1) with Authorization Bearer <key> + OpenRouter referer/title; stream the response back (Readable.fromWeb(upstream.body).pipe(res)). LOG ONLY metadata (route, alias, target, status, latency) — never prompts/keys. Bind 127.0.0.1 only; if 8787 is busy and it's our healthy proxy reuse it, else pick the next free port and update base_url to match.
E) Launcher ~/.codex-custom/custom-models/run.zsh: export CODEX_HOME + a separate CODEX_ELECTRON_USER_DATA_PATH; ensure the proxy is healthy (start detached + wait for /health, timeout ~10s); then `/usr/bin/open -n /Applications/Codex.app --env CODEX_HOME=... --env CODEX_ELECTRON_USER_DATA_PATH=... --args --user-data-dir=...`. If only the CLI exists, skip the .app and tell me the CLI is ready.
F) /Applications/Codex Custom Models.app: Info.plist (CFBundleDisplayName "Codex Custom Models", a reverse-DNS CFBundleIdentifier derived from MY username, NOT implying OpenAI); Contents/MacOS launcher = `#!/bin/zsh` + `exec ~/.codex-custom/custom-models/run.zsh "$@"`; Contents/Resources/AppIcon.icns COPIED FROM MY OWN /Applications/Codex.app at install time (do NOT download any vendor icon; if absent, skip the icon and tell me). Register with lsregister -f.

STEP 3b — WINDOWS / LINUX FALLBACK
No renamed app. In ~/.codex/config.toml add [model_providers.openrouter] base_url="https://openrouter.ai/api/v1" env_key="OPENROUTER_API_KEY" wire_api="responses", and a [profiles.openrouter] with model_provider="openrouter" + model="<id>" + approval_policy="on-request" + sandbox_mode="workspace-write". Run: codex --profile openrouter. Ollama: ensure `ollama serve` + model pulled; run `codex --oss -m <model>`.

STEP 4 — VERIFY (must pass before done)
1. macOS: `curl -fsS http://127.0.0.1:<port>/health` ok, then marker turn `CODEX_HOME=~/.codex-custom codex exec --model "<slug>" "Reply with exactly: OK-CUSTOM-MODELS"`. Confirm it returned THROUGH the proxy (one metadata log line).
2. Fallback: `codex --profile openrouter exec "Reply with exactly: OK-CUSTOM-MODELS"` (or `codex --oss -m <model> exec "Reply: OK"`).
3. If it fails, diagnose in order: proxy down -> key missing -> bad model id (404) -> port mismatch -> network. Fix the safe cases; otherwise STOP and show me the failing command + output.

STEP 5 — PRINT NEXT STEPS
macOS: "Open Finder > Applications, find 'Codex Custom Models', drag it to your Dock; switch models in the picker: <display names>." Tell me how to add a model (edit models.json + restart proxy), rotate the key (`security add-generic-password ... -U`), and uninstall cleanly (delete the app, ~/.codex-custom, the keychain item — never my normal ~/.codex). Remind me: this does not give me free AI (I pay my own OpenRouter usage; Ollama is local/free), and the proxy is loopback-only and logs no prompts/keys.

NON-NEGOTIABLE RULES
- Never write or echo any API key. Keychain (macOS) or env var (else) only.
- Never set approval_policy="never" or sandbox_mode="danger-full-access". Use safe defaults.
- Never download/embed a vendor icon; only copy from MY existing local Codex install; skip gracefully if absent.
- Idempotent: back up before overwrite, reuse a healthy proxy, no duplicate keychain/plist/config entries. Touch only ~/.codex-custom (+ the models dir) on the hero path; only APPEND to ~/.codex/config.toml on the fallback.
- If anything is ambiguous (port conflict, missing Codex/Node/Ollama, missing key), STOP and ask.
Begin with STEP 0 now.
```
