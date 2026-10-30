import os
import pathlib
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))

import config  # noqa: E402


class FetchCommandTest(unittest.TestCase):
    def test_non_shell_command_is_unchanged(self):
        self.assertEqual(config.fetch_command("python fetch.py"), ("python", "fetch.py"))

    @unittest.skipUnless(os.name == "nt", "Windows shell integration")
    def test_shell_script_runs_through_bash_on_windows(self):
        bash = r"C:\Program Files\Git\bin\bash.exe"
        with patch("config.shutil.which", return_value=bash):
            self.assertEqual(
                config.fetch_command("api3/scripts/fetch-local.sh"),
                (bash, "api3/scripts/fetch-local.sh"),
            )


if __name__ == "__main__":
    unittest.main()
