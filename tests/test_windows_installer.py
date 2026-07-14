from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


class WindowsInstallerContractTests(unittest.TestCase):
    def test_openrouter_config_uses_one_replaceable_managed_block(self):
        script = (ROOT / "install-windows.ps1").read_text(encoding="utf-8")
        self.assertIn("# BEGIN CODEX CUSTOM MODELS", script)
        self.assertIn("# END CODEX CUSTOM MODELS", script)
        self.assertNotIn("Add-Content -Path $cfg", script)


if __name__ == "__main__":
    unittest.main()
