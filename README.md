# codex-custom-models

Run **any model** inside your own copy of the Codex desktop app — OpenRouter models or **local Ollama** models — with a working in-app model picker on macOS, and a simple cross-platform fallback on Windows/Linux.

> Not affiliated with, endorsed by, or sponsored by OpenAI. "Codex" is a trademark of OpenAI. This is an independent community tool that configures the official Codex CLI/Desktop **you installed yourself**. See [NOTICE.md](NOTICE.md).

## What you get

- A **genuinely separate app** — `Codex Custom Models.app` — built from *your own* local Codex.app with its **own bundle ID** (ad-hoc re-signed) and its own `CODEX_HOME`. It won't disturb your normal Codex, and its **window controls (red/yellow/green) actually work** (see note below).
- A tiny **local alias proxy** (`127.0.0.1:8787`, run as a launchd agent) that rewrites OpenAI-style slugs → your chosen models so the Desktop picker switches between them.
- Your choice of **OpenRouter** (cloud, many models) or **Ollama** (local, private, free compute).

### Why a separate bundle (the window-controls fix)
The obvious "duplicate" — launching a 2nd instance of the *same* Codex bundle via `open -n --user-data-dir` — leaves the copy's traffic-light buttons **dead**: macOS ties window-control/activation to the bundle ID, so two instances of the same bundle get conflated. A true separate bundle fixes that. One extra wrinkle: on the inset title bar the duplicated bundle's native buttons render with a click hit-area offset, so the installer switches the primary windows to the **standard macOS title bar** (`titleBarStyle:default`) — the buttons then work on-target. Tradeoff: a slim standard title bar strip above Codex's own header. Tested on **Codex 26.616.71553**; the bundle patch is best-effort and skips gracefully if a future Codex changes its internals (see [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)).

## Honest about what this is

- **It does not give you free AI.** You bring your own OpenRouter key and pay OpenRouter per token, and your prompts go to those providers' servers. Forking the app **does not change who controls the keys or the billing**. The only fully local/private/free-compute option is **Ollama** (`codex --oss`).
- The macOS in-app picker uses an **unofficial slug-rewrite workaround**. It is not supported by OpenAI and may break on a Codex update (see openai/codex issues [#8240](https://github.com/openai/codex/issues/8240), [#24659](https://github.com/openai/codex/issues/24659)). The cross-platform fallback (`config.toml` profiles + `codex --profile`) is the stable path.

## Safety

Ships **safe defaults**: `approval_policy = "on-request"` (Codex pauses before running commands) and `sandbox_mode = "workspace-write"` (no full-disk access). The proxy binds to **loopback only**. **Never** combine auto-approve + full-access + a remote model — see [SECURITY.md](SECURITY.md).

## Install

### macOS (separate-bundle app with working window controls)
```bash
git clone https://github.com/lennoxsaint/codex-custom-models
cd codex-custom-models
./install.sh            # asks: OpenRouter or Ollama, which models, your key (stored in Keychain)
```
This copies your local Codex.app to **`/Applications/Codex Custom Models.app`** (own bundle ID, ad-hoc re-signed, `CODEX_HOME` injected), installs the proxy as a launchd agent, patches the primary windows to a standard title bar so the buttons work, and disables the fork's auto-updater (see **Updating** below). Open it from /Applications and drag it to your Dock; switch models in the picker. Re-signing only affects the **copy** — your real Codex is untouched. Remove cleanly with `./uninstall.sh`.

> The copy is ad-hoc re-signed (the only way macOS will run a re-bundled app locally). Dropped provisioned entitlements *could* affect a feature on the copy; if you hit one, the cross-platform CLI path below always works.

### Windows / Linux (fallback — CLI profile, no renamed app in v1)
```powershell
pwsh -File install-windows.ps1 -Provider openrouter -Model z-ai/glm-4.6
# then: codex --profile openrouter
```
Local models: `ollama serve` → `ollama pull qwen2.5-coder` → `codex --oss -m qwen2.5-coder`.

## Updating (and why you won't see an "improperly signed" error)
The fork's **auto-updater is disabled on purpose.** Codex updates via Sparkle, and an ad-hoc
re-signed copy can never pass Sparkle's signature check — leaving it on produces
`Update Error! The update is improperly signed and could not be validated`, and a successful
update would overwrite the fork (bundle id, CODEX_HOME, window-controls patch) anyway. The
installer removes the fork's native Sparkle addon so Codex reports the updater unavailable and
shows no dialog.

Your **real** `/Applications/Codex.app` keeps updating itself normally (untouched, valid
signature). To bring the fork up to the latest Codex, just re-fork from it:
```bash
cd codex-custom-models
./update.sh            # re-forks from your updated Codex.app; keeps your name + CODEX_HOME
```
Your models/config/proxy live in `CODEX_HOME` and are never touched, so there's nothing to
re-enter. (Already-installed an older fork that still shows the dialog? Run `./update.sh` once.)

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
