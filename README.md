# codex-custom-models

Run **any model** inside your own copy of the Codex desktop app — OpenRouter models or **local Ollama** models — with a working in-app model picker on macOS, and a simple cross-platform fallback on Windows/Linux.

> Not affiliated with, endorsed by, or sponsored by OpenAI. "Codex" is a trademark of OpenAI. This is an independent community tool that configures the official Codex CLI/Desktop **you installed yourself**. See [NOTICE.md](NOTICE.md).

## What you get

- A **second, isolated Codex instance** (its own `CODEX_HOME` + window state) that won't disturb your normal Codex.
- A tiny **local alias proxy** (`127.0.0.1:8787`) that rewrites OpenAI-style slugs → your chosen models and lets the **Desktop picker switch between them**.
- A renamed, dockable **`.app` wrapper** (macOS) using *your own* local Codex icon.
- Your choice of **OpenRouter** (cloud, many models) or **Ollama** (local, private, free compute).

## Honest about what this is

- **It does not give you free AI.** You bring your own OpenRouter key and pay OpenRouter per token, and your prompts go to those providers' servers. Forking the app **does not change who controls the keys or the billing**. The only fully local/private/free-compute option is **Ollama** (`codex --oss`).
- The macOS in-app picker uses an **unofficial slug-rewrite workaround**. It is not supported by OpenAI and may break on a Codex update (see openai/codex issues [#8240](https://github.com/openai/codex/issues/8240), [#24659](https://github.com/openai/codex/issues/24659)). The cross-platform fallback (`config.toml` profiles + `codex --profile`) is the stable path.

## Safety

Ships **safe defaults**: `approval_policy = "on-request"` (Codex pauses before running commands) and `sandbox_mode = "workspace-write"` (no full-disk access). The proxy binds to **loopback only**. **Never** combine auto-approve + full-access + a remote model — see [SECURITY.md](SECURITY.md).

## Install

### macOS (full — the in-app picker)
```bash
git clone https://github.com/lennox-saint/codex-custom-models
cd codex-custom-models
./install.sh            # asks: OpenRouter or Ollama, which models, your key (stored in Keychain)
```
Then open **Codex Custom Models** from /Applications and drag it to your Dock. Switch models in the picker.

### Windows / Linux (fallback — CLI profile, no renamed app in v1)
```powershell
pwsh -File install-windows.ps1 -Provider openrouter -Model z-ai/glm-4.6
# then: codex --profile openrouter
```
Local models: `ollama serve` → `ollama pull qwen2.5-coder` → `codex --oss -m qwen2.5-coder`.

## Pick your models
Edit `examples/models.json` (or pass `--models <file>`):
```json
{ "provider": "openrouter",
  "models": [ { "slug": "gpt-5.5", "display_name": "GLM [OpenRouter]", "target": "z-ai/glm-4.6", "context_window": 200000 } ] }
```
`slug` is what the picker shows; `target` is the real model id. Confirm `target` ids at <https://openrouter.ai/models>.

## How it works
`docs/HOW-IT-WORKS.md` — isolated home + alias proxy + catalog. Uninstall cleanly with `./uninstall.sh` (never touches your normal `~/.codex`).

## Prefer to have an agent build it for you?
Paste `docs/MEGA-PROMPT.md` into your own Codex/Claude Code and it will build this on your machine, step by step.

---

**Get the full walkthrough, the copy-paste prompt, and help — free inside Codex Club:** <https://www.skool.com/codexclub>
