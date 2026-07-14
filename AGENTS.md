# Agent Setup Contract

This repository builds a local, separately identified copy of the user's installed OpenAI desktop app and routes its Codex workspace through OpenRouter or Ollama.

## When The User Says "Set This Up"

1. Clone or update this repository. Read `README.md` and `SECURITY.md`.
2. Run `./scripts/preflight.sh` and show the user the detected source name/version and any exact blocker.
3. If the user only says “install this,” use OpenRouter with `examples/models.openrouter.json`, the release-verified Codex Club pack. Ask for 1-6 model IDs only when they request a different set. Recommend Ollama when local privacy is their priority. Never ask the user to paste an API key into chat.
4. For OpenRouter, run:

   ```bash
   ./install.sh --provider openrouter --models examples/models.openrouter.json --verify --launch
   ```

   Use repeatable `--model 'provider/model|Display Name'` flags only for a user-selected override. The installer opens OpenRouter's official PKCE authorization page when Keychain has no credential.
5. Verify the app bundle, isolated `CODEX_HOME`, proxy health, model mappings, marker response, and a new metadata receipt in the proxy log.
   - The isolated profile intentionally disables namespace-producing OpenAI integrations that non-OpenAI endpoints reject. Do not re-enable apps, plugins, browser/computer use, goals, ImageGen, multi-agent, workspace-dependency or hook features just to make the picker look more complete.
   - The marker verifier restores the exact pre-marker config snapshot so Codex cannot persist a project trust entry during verification.
6. On macOS, open the installed app and confirm a process is running from its own bundle. Add it to the Dock only if the user asked or the setup request clearly includes that outcome.
   - First launch may ask whether the ad-hoc copy can read the official `Codex Storage Key`. Recommend **Deny** to keep the custom profile isolated; the OpenRouter credential lives in a separate Keychain item.
   - macOS may ask for folder access when the user chooses a workspace. Let the user approve only folders they intend the custom app to edit.
7. Report the exact installed path, source version, bundle ID, model mappings, test outcome, and any skipped proof.

## Hard Boundaries

- Never download, commit, upload, redistribute, or mutate an OpenAI app bundle. Copy only the user's locally installed, signature-verified `/Applications/ChatGPT.app` or legacy `/Applications/Codex.app`.
- Never accept, print, log, echo, or write an OpenRouter key. Use `scripts/openrouter-login.mjs` and macOS Keychain.
- Never weaken `approval_policy = "on-request"` or `sandbox_mode = "workspace-write"` during setup.
- Never overwrite an app that lacks `CCMManagedBy=codex-custom-models` unless the user explicitly reviewed and approved that exact path.
- A structural pass is not a model pass. Use `--verify` for a real marker turn unless the user declines the small provider cost.
- A successful `open` call is not launch proof. Confirm the `.real` copied executable remains alive after startup.
- Be precise: OpenRouter models power the Codex workspace, not the unified app's Chat or Work surfaces.

## Development Gate

Run before committing:

```bash
python3 -m unittest discover -s tests -v
node --test tests/*.test.mjs
node --check src/proxy.mjs scripts/*.mjs
node scripts/validate-member-package.mjs examples/models.openrouter.json --live
bash -n install.sh update.sh uninstall.sh scripts/*.sh
git diff --check
```
