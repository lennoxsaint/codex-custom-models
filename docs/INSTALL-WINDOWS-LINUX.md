# Windows and Linux

The separately named ChatGPT desktop copy is currently a **macOS-only** path. Windows and Linux use Codex CLI profiles instead.

## Windows

```powershell
$env:OPENROUTER_API_KEY = Read-Host -MaskInput "OpenRouter key"
pwsh -File install-windows.ps1 -Provider openrouter -Model z-ai/glm-5.2
codex --profile openrouter exec "Reply with exactly: OK-CUSTOM-MODELS"
```

Use your normal secure environment/credential manager for persistence; never commit the key or paste it into an agent conversation.

The installer owns one marked block in `~/.codex/config.toml` and replaces that block on reruns. It refuses to overwrite an existing unmarked `openrouter` provider/profile, so a hand-written configuration is never silently changed.

## Linux

Add an OpenRouter provider and profile to `~/.codex/config.toml` using `templates/config.crossplatform.toml.tmpl`, set `OPENROUTER_API_KEY` in your secure shell environment, then run:

```bash
codex --profile openrouter exec 'Reply with exactly: OK-CUSTOM-MODELS'
```

For Ollama on either platform:

```bash
ollama serve
ollama pull qwen2.5-coder
codex --oss -m qwen2.5-coder
```

These paths do not create a second desktop application.
