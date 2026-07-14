# Agent handoff prompt

The old multi-page copy/paste prompt duplicated implementation details and went stale when OpenAI merged Codex into the ChatGPT desktop app. The repository is now the executable contract.

Give an agent this:

```text
Install this on my Mac with the verified Codex Club model pack. Follow the repository's AGENTS.md, never ask me to paste a key into chat, and verify the app, proxy, exact model mapping, and a real marker turn before saying it works:
https://github.com/lennoxsaint/codex-custom-models
```

For an unattended-safe structural setup where the OpenRouter credential already exists in Keychain:

```bash
./install.sh --provider openrouter --models examples/models.openrouter.json --non-interactive --launch
```

Add `--verify` to make a real provider request. That call may incur a small OpenRouter charge.
