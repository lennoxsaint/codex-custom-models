from __future__ import annotations

import json
import plistlib
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
HELPER = REPO_ROOT / "scripts" / "app_bundle.py"


def make_app(
    applications_dir: Path,
    name: str,
    *,
    executable: str,
    bundle_id: str = "com.openai.codex",
    display_name: str | None = None,
) -> Path:
    app = applications_dir / f"{name}.app"
    contents = app / "Contents"
    macos = contents / "MacOS"
    macos.mkdir(parents=True)
    (macos / executable).write_text("fixture", encoding="utf-8")
    with (contents / "Info.plist").open("wb") as handle:
        plistlib.dump(
            {
                "CFBundleIdentifier": bundle_id,
                "CFBundleExecutable": executable,
                "CFBundleDisplayName": display_name or name,
                "CFBundleName": display_name or name,
                "CFBundleShortVersionString": "26.707.31428",
            },
            handle,
        )
    return app


class AppBundleTests(unittest.TestCase):
    def run_helper(self, *args: str, expect_ok: bool = True) -> subprocess.CompletedProcess[str]:
        result = subprocess.run(
            ["python3", str(HELPER), *args],
            check=False,
            capture_output=True,
            text=True,
        )
        if expect_ok and result.returncode != 0:
            self.fail(result.stderr)
        return result

    def test_detect_prefers_unified_chatgpt_bundle(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            apps = Path(temp)
            make_app(apps, "Codex", executable="Codex")
            chatgpt = make_app(apps, "ChatGPT", executable="ChatGPT")

            result = self.run_helper("detect", "--applications-dir", str(apps))
            payload = json.loads(result.stdout)

            self.assertEqual(payload["path"], str(chatgpt.resolve()))
            self.assertEqual(payload["executable"], "ChatGPT")
            self.assertEqual(payload["product_generation"], "unified_chatgpt")

    def test_detect_falls_back_to_legacy_codex_bundle(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            apps = Path(temp)
            codex = make_app(apps, "Codex", executable="Codex")

            result = self.run_helper("detect", "--applications-dir", str(apps))
            payload = json.loads(result.stdout)

            self.assertEqual(payload["path"], str(codex.resolve()))
            self.assertEqual(payload["product_generation"], "legacy_codex")

    def test_explicit_source_override_wins(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            apps = Path(temp)
            make_app(apps, "ChatGPT", executable="ChatGPT")
            preview = make_app(apps, "ChatGPT Preview", executable="ChatGPT Preview")

            result = self.run_helper("inspect", str(preview))
            payload = json.loads(result.stdout)

            self.assertEqual(payload["path"], str(preview.resolve()))
            self.assertEqual(payload["executable"], "ChatGPT Preview")

    def test_rejects_non_openai_lookalike_bundle(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            apps = Path(temp)
            fake = make_app(
                apps,
                "ChatGPT",
                executable="ChatGPT",
                bundle_id="example.fake.chatgpt",
            )

            result = self.run_helper("inspect", str(fake), expect_ok=False)

            self.assertNotEqual(result.returncode, 0)
            self.assertIn("unexpected bundle identifier", result.stderr)

    def test_rejects_missing_declared_executable(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            apps = Path(temp)
            app = make_app(apps, "ChatGPT", executable="ChatGPT")
            (app / "Contents" / "MacOS" / "ChatGPT").unlink()

            result = self.run_helper("inspect", str(app), expect_ok=False)

            self.assertNotEqual(result.returncode, 0)
            self.assertIn("declared executable is missing", result.stderr)


if __name__ == "__main__":
    unittest.main()
