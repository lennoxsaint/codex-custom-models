# Troubleshooting

## "Update Error! The update is improperly signed and could not be validated"
This is **expected on a fork** if the updater is left on, and the installer disables it for you.

The ChatGPT/Codex desktop app updates via **Sparkle**. The managed copy is ad-hoc re-signed, so when Sparkle downloads a
new OpenAI-signed build it can't validate it against the copy's signature — Sparkle
error `4005` (`EdDSA` `3002` underneath) → that dialog. Worse, if it *could* install, the update
would overwrite the fork (bundle id, CODEX_HOME, title-bar patch) and undo everything.

`scripts/duplicate-codex-app.sh` therefore **disables the fork's updater**: it removes the native
`sparkle.node` addon (Codex then logs `Updater unavailable after init. reason="failed to load
native sparkle addon"` and silently ignores all checks — no dialog) and sets
`SUEnableAutomaticChecks=false` / `SUScheduledCheckInterval=0` / `SUAutomaticallyUpdate=false`.

**To actually update**, run `./update.sh`. Your real `/Applications/ChatGPT.app` updates itself
normally (untouched, valid signature); `update.sh` re-forks from it, preserving your app name and
CODEX_HOME (models/config/proxy are stored in CODEX_HOME and never touched). If you have an older
fork still showing the dialog, just run `./update.sh` once to rebuild it with the updater disabled.

## Window buttons (red/yellow/green) don't respond on the duplicate
This was the original reason for the separate-bundle approach. Two causes, both handled by `install.sh` / `scripts/duplicate-codex-app.sh`:

1. **Same-bundle conflation.** Launching a second instance of the same bundle (`open -n --user-data-dir`) makes macOS conflate the windows. Fix: a genuinely separate bundle ID created from your verified local ChatGPT/Codex app.
2. **Inset title-bar hit-area offset.** In the duplicated bundle, `titleBarStyle:hiddenInset`'s native buttons render with the clickable area slightly above the dots (you'd have to click above them). Fix: the installer byte-patches the primary windows to `titleBarStyle:default` (standard title bar → OS-managed buttons with correct hit-areas).

If a future Codex changes its minified internals, the byte-patch prints a WARN and skips — the app still runs, but you may see the hit-area offset. In that case: use the keyboard (⌘M minimize, ⌘W close, ⌃⌘F fullscreen) or re-run after the patch is updated for the new version.

## "App is damaged / can't be opened"
The copy is ad-hoc re-signed and de-quarantined by the installer. If macOS still blocks it:
Re-run `./update.sh 'ChatGPT OpenRouter Models'`. The managed installer stages, signs, and verifies a clean copy. Avoid bypassing Gatekeeper manually.

## App bounces in the Dock then never opens
Almost always a **stale Electron singleton lock** from a previous instance that crashed or was force-quit. On the next launch Electron tries to hand off to the now-dead instance, bounces for ~30s, and quits before a window appears. Fix — fully quit the app, then remove the leftover lock/socket files from its Electron user-data dir and relaunch:

```
rm -f "$HOME/Library/Application Support/ChatGPT OpenRouter Models/Singleton"*
```

Replace `ChatGPT OpenRouter Models` with your `--app-name` if you renamed it. Nothing is lost; Electron recreates these lock/socket files.

## Models don't respond / proxy errors (OpenRouter)
The proxy runs as a launchd agent. Check it:
`curl -fsS http://127.0.0.1:8787/health` and `~/.codex-custom/proxy.stderr.log`.
Restart: `launchctl bootout gui/$(id -u)/com.codexcustommodels.proxy.8787; launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.codexcustommodels.proxy.8787.plist`

## Preflight reports `official_source_signature_invalid`
Do not bypass this for a real installation. Update or reinstall the official ChatGPT desktop app from OpenAI, then rerun `./scripts/preflight.sh`. The test-only `CCM_SKIP_SOURCE_SIGNATURE_CHECK` escape hatch is not a member-installation path.

## OpenRouter authorization is required
Run `node scripts/openrouter-login.mjs`. It opens OpenRouter's official authorization page and stores the returned credential directly in Keychain. Do not paste a key into an agent chat.

## First launch asks for `Codex Storage Key`
The official app's encrypted-storage item is access-controlled to OpenAI's signature. The ad-hoc signed copy is correctly treated as a different application, so macOS asks before sharing it. Choose **Deny** to keep the custom profile isolated. The OpenRouter credential uses the separate `codex-custom-models-api-key` Keychain service and continues to work.

## First launch asks for Desktop, Documents, or Downloads access
This is normal macOS folder protection. Approve only folders you intentionally want the custom Codex workspace to edit. Denying a folder does not break the OpenRouter proxy or model picker.

## Re-signing affected a feature on the copy
Ad-hoc re-signing drops provisioned entitlements on the COPY (your real Codex is untouched). If a feature misbehaves on the duplicate, use the cross-platform CLI path (`codex --profile openrouter` / `codex --oss`) which needs no re-sign.

## Tested on
Unified ChatGPT/Codex `26.707.31428` and legacy Codex `26.616.71553`/`26.616.81150`. The bundle and signing steps are version-agnostic; only the optional title-bar byte patch depends on bundled code shape and skips gracefully when absent.

## Why the standard title bar (and not a sleek single bar)
We tested single-bar styles (`titleBarStyle:hidden` and `hiddenInset`) to drop the extra
strip. In the re-signed duplicate, Codex's own HTML header overlaps the native traffic-lights
in those modes and **swallows the clicks** (buttons appear on hover but don't fire). Only
`titleBarStyle:default` — where the buttons live in their own title-bar strip above the web
content — clicks reliably. So the slim standard title bar is **intentional**: it's the price of
working window controls. Reclaiming a single bar would require patching Codex's own header CSS
(fragile + version-specific) and is deliberately not done here.
