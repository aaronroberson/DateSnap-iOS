import unittest
import sys
import os

# Ensure scripts directory is in sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from download_screens import resolve_config, build_headers

class TestDownloadScreensConfig(unittest.TestCase):
    def test_cli_overrides_env_var(self):
        env = {
            "STITCH_PROJECT_ID": "env_stitch_id",
            "GOOGLE_CLOUD_PROJECT": "env_google_id"
        }
        cli_args = [
            "--project-id", "cli_stitch_id",
            "--user-project", "cli_google_id"
        ]
        project_id, user_project = resolve_config(cli_args=cli_args, env=env)
        self.assertEqual(project_id, "cli_stitch_id")
        self.assertEqual(user_project, "cli_google_id")

    def test_env_var_fallback(self):
        env = {
            "STITCH_PROJECT_ID": "env_stitch_id",
            "GOOGLE_USER_PROJECT": "env_user_proj_id"
        }
        cli_args = []
        project_id, user_project = resolve_config(cli_args=cli_args, env=env)
        self.assertEqual(project_id, "env_stitch_id")
        self.assertEqual(user_project, "env_user_proj_id")

    def test_header_building_with_user_project(self):
        token = "test_token_123"
        user_project = "my-gcp-project"
        warnings = []
        headers = build_headers(token, user_project=user_project, warn_func=warnings.append)

        self.assertEqual(headers["Authorization"], "Bearer test_token_123")
        self.assertEqual(headers["X-Goog-User-Project"], "my-gcp-project")
        self.assertEqual(len(warnings), 0)

    def test_header_building_without_user_project(self):
        token = "test_token_123"
        warnings = []
        headers = build_headers(token, user_project=None, warn_func=warnings.append)

        self.assertEqual(headers["Authorization"], "Bearer test_token_123")
        self.assertNotIn("X-Goog-User-Project", headers)
        self.assertEqual(len(warnings), 1)
        self.assertIn("Warning: Google User Project ID not provided", warnings[0])

if __name__ == "__main__":
    unittest.main()
