# Security

## Threat model
You are wiring an AI agent that can run shell commands on your machine to a **remote, third-party model** you don't control. A model hallucination or a prompt-injection in any file/web content the agent reads can become **arbitrary code execution**. Treat it accordingly.

## Safe defaults (shipped)
- `approval_policy = "on-request"` — Codex pauses and asks before running generated commands.
- `sandbox_mode = "workspace-write"` — writes confined to the workspace; no full-disk access.
- No `[projects.*] trust_level = "trusted"` block is shipped.
- The proxy binds to `127.0.0.1` only. Never bind `0.0.0.0`.

## The one anti-pattern: never combine these
**auto-approve (`approval_policy="never"`) + full access (`sandbox_mode="danger-full-access"`) + a remote model = arbitrary code execution.** Do not do it. If a blog/comment tells you to "just set approval_policy never to stop the prompts," don't. CI in this repo fails the build if any of these values appear.

## Key handling
- The OpenRouter key is **never** written to a config file, log, shell history, or commit.
- macOS: stored in the Keychain (`codex-custom-models-api-key`), read at request time by the proxy. The installer reads it via a hidden `read -s` and pipes it to `security` over **stdin** (not as a CLI arg).
- Windows/Linux: an `OPENROUTER_API_KEY` env var (`env_key`), never inline in config.
- The proxy logs **only metadata** (route, alias, target, status, latency) — never prompts, completions, headers, or keys.
- `.gitignore` excludes `.env` and `*.icns`. CI runs gitleaks.

## Before you screen-share / record
Your key is in the Keychain/env. Don't reveal it on camera.

## Cost
Set a spend limit on your OpenRouter account before you start — a runaway agent loop costs money. Ollama (`--oss`) has no per-token cost.
