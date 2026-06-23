# Troubleshooting

## Window buttons (red/yellow/green) don't respond on the duplicate
This was the original reason for the separate-bundle approach. Two causes, both handled by `install.sh` / `scripts/duplicate-codex-app.sh`:

1. **Same-bundle conflation.** Launching a 2nd instance of the *same* Codex bundle (`open -n --user-data-dir`) makes macOS conflate the two instances' windows → traffic-lights dead. Fix: a genuinely separate bundle ID (this repo copies + ad-hoc re-signs your local Codex.app).
2. **Inset title-bar hit-area offset.** In the duplicated bundle, `titleBarStyle:hiddenInset`'s native buttons render with the clickable area slightly above the dots (you'd have to click above them). Fix: the installer byte-patches the primary windows to `titleBarStyle:default` (standard title bar → OS-managed buttons with correct hit-areas).

If a future Codex changes its minified internals, the byte-patch prints a WARN and skips — the app still runs, but you may see the hit-area offset. In that case: use the keyboard (⌘M minimize, ⌘W close, ⌃⌘F fullscreen) or re-run after the patch is updated for the new version.

## "App is damaged / can't be opened"
The copy is ad-hoc re-signed and de-quarantined by the installer. If macOS still blocks it:
`xattr -cr "/Applications/Codex Custom Models.app" && codesign --force --deep --sign - "/Applications/Codex Custom Models.app"`

## Models don't respond / proxy errors (OpenRouter)
The proxy runs as a launchd agent. Check it:
`curl -fsS http://127.0.0.1:8787/health` and `~/.codex-custom/proxy.stderr.log`.
Restart: `launchctl unload ~/Library/LaunchAgents/com.codexcustommodels.proxy.plist && launchctl load ~/Library/LaunchAgents/com.codexcustommodels.proxy.plist`

## Re-signing affected a feature on the copy
Ad-hoc re-signing drops provisioned entitlements on the COPY (your real Codex is untouched). If a feature misbehaves on the duplicate, use the cross-platform CLI path (`codex --profile openrouter` / `codex --oss`) which needs no re-sign.

## Tested on
Codex 26.616.71553. Other versions: the separate-bundle + re-sign steps are version-agnostic; only the title-bar byte-patch depends on Codex's bundled code shape (skips gracefully if not found).
