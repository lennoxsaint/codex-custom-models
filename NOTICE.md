# Notice / Disclaimer

This is an **independent, community tool**. It is **not affiliated with,
endorsed by, or sponsored by OpenAI**. "Codex" is a trademark of OpenAI; it is
used here only nominatively to describe the official Codex CLI/Desktop that
**you installed yourself**. This project does not bundle, redistribute, or
modify OpenAI's software or assets.

- **No OpenAI assets are shipped.** The optional macOS app icon is copied from
  *your own* local `/Applications/Codex.app` at install time. If that icon is
  absent, a neutral fallback icon (original, MIT-licensed) is used. `*.icns`
  files are git-ignored and never committed.
- **Rename before redistribution.** If you redistribute a built app, give it a
  name that does not imply OpenAI ownership and use your own icon.
- This tool configures clients you are entitled to use, with API keys you own.
  Respect OpenAI's and OpenRouter's Terms of Service.

## On the ad-hoc re-sign (v2)
The macOS installer copies **your own locally-installed** `Codex.app`, changes the copy's
bundle identifier/name, and ad-hoc re-signs the copy so macOS will run it locally. No OpenAI
binary is downloaded or redistributed by this repo — the copy is created on your machine from
software you already installed. Re-signing only affects the copy; your real Codex is untouched.
