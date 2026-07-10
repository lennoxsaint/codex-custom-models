# ChatGPT Custom Models for Codex

Create a separate copy of OpenAI's **unified ChatGPT desktop app** whose **Codex workspace** can run models from OpenRouter or local Ollama. The copy gets its own app name, bundle ID, settings, history, model picker, and Dock icon. Your official ChatGPT app stays untouched.

> July 2026 compatibility: [OpenAI's July 9 release](https://help.openai.com/en/articles/6825453-chatgpt-app-features) brought Chat, Work, and Codex into one desktop app. Existing Codex installations update to `/Applications/ChatGPT.app`. This installer supports the unified app and retains a legacy `Codex.app` fallback.

## Give This Link To Your Agent

Send this one sentence to Codex or another capable coding agent:

> Set this up on my Mac, ask which OpenRouter models I want, and verify it end to end: https://github.com/lennoxsaint/codex-custom-models

The repository's [AGENTS.md](AGENTS.md) gives the agent the complete safe setup contract. The agent will:

1. Clone the repository and run machine-readable preflight.
2. Ask which OpenRouter models you want.
3. Open OpenRouter in your browser for authorization. **Never paste an API key into chat.**
4. Build `ChatGPT OpenRouter Models.app` from your own verified local ChatGPT app.
5. Run structural checks and a real marker turn, launch the copy, and report exact proof.

The unavoidable human steps are approving OpenRouter in the browser and responding to normal first-launch macOS permission prompts. Usage is billed to your OpenRouter account; this project does not provide free model access.

## Manual Install

Requirements: macOS 14+, Apple Silicon, the current official ChatGPT desktop app, Node.js 18+, and Xcode Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/lennoxsaint/codex-custom-models.git
cd codex-custom-models
./scripts/preflight.sh
./install.sh \
  --provider openrouter \
  --model 'z-ai/glm-5.2|GLM 5.2' \
  --model 'moonshotai/kimi-k2.7-code|Kimi K2.7 Code' \
  --verify \
  --launch
```

`--model` accepts a live OpenRouter model ID and an optional plain-English display name separated by `|`. The installer validates each ID against OpenRouter's public catalog and uses its real context window. Repeat the flag up to six times.

For local models:

```bash
./install.sh --provider ollama --models examples/models.ollama.json --launch
```

## What Gets Created

- `/Applications/ChatGPT OpenRouter Models.app`: a separately identified, ad-hoc signed copy built locally from `/Applications/ChatGPT.app`.
- `~/.codex-custom`: isolated Codex configuration, Electron profile, catalog, proxy, history, and receipts.
- `~/Library/LaunchAgents/com.codexcustommodels.proxy.8787.plist`: a loopback-only alias proxy.
- Keychain service `codex-custom-models-api-key`: the user-controlled OpenRouter credential returned by the official PKCE authorization flow.

The repository ships **no OpenAI binary, icon, credential, or prebuilt application**.

## What It Does Not Do

- It does not route ChatGPT **Chat** or **Work** through OpenRouter. It configures the **Codex** surface in the unified desktop app.
- It does not bypass subscriptions, provider billing, safety checks, or model terms.
- It does not modify, replace, re-sign, or disable updates on the official `/Applications/ChatGPT.app`.
- It does not publish or redistribute the locally created copy.

This relies on an unofficial Codex catalog/alias-proxy workaround and may need maintenance when OpenAI changes the desktop bundle. The CLI profile remains the less polished fallback.

## Safety

- Source bundle ID must be `com.openai.codex` and its code signature must belong to OpenAI team `2DC432GLL2`.
- Default agent permissions remain `approval_policy = "on-request"` and `sandbox_mode = "workspace-write"`.
- The proxy binds only to `127.0.0.1` and logs route/model/status/latency metadata, never prompts, completions, or credentials.
- OpenRouter authentication uses OAuth PKCE and stores the resulting credential directly in macOS Keychain.
- The installer refuses to overwrite an unrelated app with the same name.

Read [SECURITY.md](SECURITY.md) before increasing Codex permissions.

## Updating

Let the official ChatGPT app update normally, then rebuild the managed copy:

```bash
cd codex-custom-models
git pull --ff-only
./update.sh 'ChatGPT OpenRouter Models'
```

The managed copy's Sparkle updater is disabled because an ad-hoc signed fork cannot validate OpenAI's update package. `update.sh` re-copies from the current verified official app while preserving models, credentials, and isolated history.

## Verification And Removal

```bash
./scripts/verify.sh --app-name 'ChatGPT OpenRouter Models' --home "$HOME/.codex-custom" --port 8787
./uninstall.sh --app-name 'ChatGPT OpenRouter Models'
```

See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md), [docs/HOW-IT-WORKS.md](docs/HOW-IT-WORKS.md), and the short [agent handoff prompt](docs/MEGA-PROMPT.md).

Independent community project; not affiliated with or endorsed by OpenAI or OpenRouter. See [NOTICE.md](NOTICE.md).

**Codex Club walkthrough and support:** <https://www.skool.com/codexclub>
