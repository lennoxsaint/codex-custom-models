from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


class SafeConfigContractTests(unittest.TestCase):
    def test_openrouter_profile_disables_unsupported_namespace_tool_sources(self):
        template = (ROOT / "templates" / "config.isolated-home.toml.tmpl").read_text(encoding="utf-8")
        required_disabled_features = (
            "apps",
            "browser_use",
            "computer_use",
            "goals",
            "image_generation",
            "in_app_browser",
            "multi_agent",
            "plugins",
            "tool_suggest",
            "workspace_dependencies",
            "skill_mcp_dependency_install",
            "hooks",
        )
        self.assertIn("[features]", template)
        for feature in required_disabled_features:
            self.assertIn(f"{feature} = false", template)

    def test_marker_verifier_restores_the_config_snapshot(self):
        verifier = (ROOT / "scripts" / "verify.sh").read_text(encoding="utf-8")
        self.assertIn("VERIFY_CONFIG_BACKUP", verifier)
        self.assertIn('cp -p "$VERIFY_CONFIG_BACKUP" "$HOME_DIR/config.toml"', verifier)


if __name__ == "__main__":
    unittest.main()
