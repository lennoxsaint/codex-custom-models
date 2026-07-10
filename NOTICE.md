# Notice / Disclaimer

This is an **independent, community tool**. It is **not affiliated with,
endorsed by, or sponsored by OpenAI**. "ChatGPT" and "Codex" are trademarks of OpenAI; they are
used here only nominatively to describe the official ChatGPT/Codex software that
**you installed yourself**. This project does not bundle or redistribute
OpenAI's software or assets. It modifies only a local copy created from the
user's own verified installation; the official source application is untouched.

- **No OpenAI assets are shipped.** The optional macOS app icon is copied from
  *your own* local `/Applications/ChatGPT.app` or legacy `/Applications/Codex.app`
  at install time as part of the local bundle copy. `*.icns` files are git-ignored
  and never committed.
- **Do not redistribute the built copy.** Other users should run this repository
  against their own official local installation.
- This tool configures clients you are entitled to use, with API keys you own.
  Respect OpenAI's and OpenRouter's Terms of Service.

## On the ad-hoc re-sign (v2)
The macOS installer copies **your own locally-installed** `ChatGPT.app` (or legacy `Codex.app`), changes the copy's
bundle identifier/name, and ad-hoc re-signs the copy so macOS will run it locally. No OpenAI
binary is downloaded or redistributed by this repo — the copy is created on your machine from
software you already installed. Re-signing only affects the copy; your official ChatGPT/Codex app is untouched.
