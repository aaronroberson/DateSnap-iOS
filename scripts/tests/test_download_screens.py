import unittest
import os
import sys

# Ensure scripts directory is in sys.path so download_screens can be imported
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from download_screens import resolve_project_id, build_headers, parse_args


class TestDownloadScreens(unittest.TestCase):

    def setUp(self):
        # Save original environment
        self._orig_env = os.environ.copy()

    def tearDown(self):
        # Restore original environment
        os.environ.clear()
        os.environ.update(self._orig_env)

    def test_resolve_project_id_cli_override(self):
        os.environ["STITCH_PROJECT_ID"] = "env_stitch_id"
        os.environ["PROJECT_ID"] = "env_id"
        result = resolve_project_id("cli_id")
        self.assertEqual(result, "cli_id")

    def test_resolve_project_id_stitch_env(self):
        os.environ["STITCH_PROJECT_ID"] = "env_stitch_id"
        os.environ["PROJECT_ID"] = "env_id"
        result = resolve_project_id()
        self.assertEqual(result, "env_stitch_id")

    def test_resolve_project_id_project_env_alias(self):
        if "STITCH_PROJECT_ID" in os.environ:
            del os.environ["STITCH_PROJECT_ID"]
        os.environ["PROJECT_ID"] = "env_id"
        result = resolve_project_id()
        self.assertEqual(result, "env_id")

    def test_resolve_project_id_none(self):
        if "STITCH_PROJECT_ID" in os.environ:
            del os.environ["STITCH_PROJECT_ID"]
        if "PROJECT_ID" in os.environ:
            del os.environ["PROJECT_ID"]
        result = resolve_project_id()
        self.assertIsNone(result)

    def test_build_headers_with_project_id(self):
        headers = build_headers("test-token", "my-project-123")
        self.assertEqual(headers.get("Authorization"), "Bearer test-token")
        self.assertEqual(headers.get("X-Goog-User-Project"), "my-project-123")

    def test_build_headers_without_project_id(self):
        headers = build_headers("test-token", None)
        self.assertEqual(headers.get("Authorization"), "Bearer test-token")
        self.assertNotIn("X-Goog-User-Project", headers)

    def test_parse_args_project_id(self):
        parsed = parse_args(["--project-id", "custom-proj"])
        self.assertEqual(parsed.project_id, "custom-proj")

    def test_parse_args_default(self):
        parsed = parse_args([])
        self.assertIsNone(parsed.project_id)


if __name__ == "__main__":
    unittest.main()
