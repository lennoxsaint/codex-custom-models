#!/usr/bin/env python3
"""Inspect the locally installed OpenAI Codex/ChatGPT desktop bundle."""

from __future__ import annotations

import argparse
import json
import plistlib
import sys
from pathlib import Path
from typing import Any


EXPECTED_BUNDLE_ID = "com.openai.codex"
SOURCE_CANDIDATES = (
    ("ChatGPT.app", "unified_chatgpt"),
    ("Codex.app", "legacy_codex"),
)


class BundleError(RuntimeError):
    pass


def inspect_bundle(app_path: Path, generation: str | None = None) -> dict[str, Any]:
    app_path = app_path.expanduser().resolve()
    plist_path = app_path / "Contents" / "Info.plist"
    if not app_path.is_dir() or not plist_path.is_file():
        raise BundleError(f"OpenAI desktop app bundle not found at {app_path}")

    try:
        with plist_path.open("rb") as handle:
            plist = plistlib.load(handle)
    except (OSError, plistlib.InvalidFileException) as exc:
        raise BundleError(f"could not read {plist_path}: {exc}") from exc

    bundle_id = plist.get("CFBundleIdentifier")
    if bundle_id != EXPECTED_BUNDLE_ID:
        raise BundleError(
            f"unexpected bundle identifier {bundle_id!r} at {app_path}; "
            f"expected {EXPECTED_BUNDLE_ID!r}"
        )

    executable = plist.get("CFBundleExecutable")
    if not isinstance(executable, str) or not executable:
        raise BundleError(f"CFBundleExecutable is missing from {plist_path}")
    executable_path = app_path / "Contents" / "MacOS" / executable
    if not executable_path.is_file():
        raise BundleError(f"declared executable is missing: {executable_path}")

    if generation is None:
        generation = "unified_chatgpt" if executable == "ChatGPT" else "legacy_codex"

    return {
        "path": str(app_path),
        "bundle_id": bundle_id,
        "display_name": plist.get("CFBundleDisplayName") or plist.get("CFBundleName") or app_path.stem,
        "executable": executable,
        "executable_path": str(executable_path),
        "version": plist.get("CFBundleShortVersionString") or "unknown",
        "product_generation": generation,
    }


def detect_bundle(applications_dir: Path) -> dict[str, Any]:
    for app_name, generation in SOURCE_CANDIDATES:
        candidate = applications_dir.expanduser() / app_name
        if candidate.is_dir():
            return inspect_bundle(candidate, generation)
    looked = ", ".join(str(applications_dir / name) for name, _ in SOURCE_CANDIDATES)
    raise BundleError(f"no supported OpenAI desktop app found; looked for {looked}")


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser(description=__doc__)
    subparsers = root.add_subparsers(dest="command", required=True)

    detect = subparsers.add_parser("detect", help="detect ChatGPT.app, then legacy Codex.app")
    detect.add_argument("--applications-dir", default="/Applications")
    detect.add_argument("--field", choices=("path", "executable", "display_name", "version", "product_generation"))

    inspect = subparsers.add_parser("inspect", help="inspect an explicit app bundle")
    inspect.add_argument("path")
    inspect.add_argument("--field", choices=("path", "executable", "display_name", "version", "product_generation"))
    return root


def main() -> int:
    args = parser().parse_args()
    try:
        if args.command == "detect":
            payload = detect_bundle(Path(args.applications_dir))
        else:
            payload = inspect_bundle(Path(args.path))
    except BundleError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    field = getattr(args, "field", None)
    if field:
        print(payload[field])
    else:
        print(json.dumps(payload, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
