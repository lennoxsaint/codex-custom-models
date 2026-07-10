# Agent handoff prompt

The old multi-page copy/paste prompt duplicated implementation details and went stale when OpenAI merged Codex into the ChatGPT desktop app. The repository is now the executable contract.

Give an agent this:

```text
Set this up on my Mac. Follow the repository's AGENTS.md, ask which OpenRouter models I want, never ask me to paste a key into chat, and verify the app, proxy, model mapping, and a real marker turn before saying it works:
https://github.com/lennoxsaint/codex-custom-models
```

For an unattended-safe structural setup where the OpenRouter credential already exists in Keychain:

```bash
./install.sh --provider openrouter --model 'z-ai/glm-5.2|GLM 5.2' --non-interactive --launch
```

Add `--verify` to make a real provider request. That call may incur a small OpenRouter charge.
