"""Settings: the agent's .env reaches FETCH_CMD, and the agent key never falls back to another wallet."""
import os
import pathlib
import sys
import tempfile
import unittest
from unittest import mock

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))

import config  # noqa: E402
import pulse_agent  # noqa: E402


class ConfigTest(unittest.TestCase):
    def test_the_env_file_is_exported_for_the_fetch_command(self):
        # review finding: PAYER_PRIVATE_KEY in api3/agent/.env never reached fetch-evidence.sh (exit 2)
        with tempfile.TemporaryDirectory() as d, mock.patch.dict(os.environ, {"AGENT_PROFILE": "demo"}, clear=True), \
                mock.patch.object(config, "AGENT_DIR", pathlib.Path(d)):
            (pathlib.Path(d) / ".env").write_text("PAYER_PRIVATE_KEY=0xpayer   # aUSD wallet\n"
                                                  "AGENT_PROFILE=prod\nPULSE_PLUS_ADDRESS=\n")
            cfg = config.load(require_chain=False)
            self.assertEqual(os.environ["PAYER_PRIVATE_KEY"], "0xpayer")  # child processes inherit it
            self.assertEqual(cfg.profile, "demo")  # the real environment wins over the file
            self.assertNotIn("PULSE_PLUS_ADDRESS", os.environ)  # an empty value means not set

    def test_the_agent_key_never_falls_back_to_the_buyer_wallet(self):
        cfg = config.load(env={"EVM_PRIVATE_KEY": "0xbuyer"}, require_chain=False)
        self.assertEqual(cfg.agent_key, "")
        with self.assertRaises(ValueError):
            config.load(env={"EVM_PRIVATE_KEY": "0xbuyer", "PULSE_PLUS_ADDRESS": "0xc", "EVM_RPC_URL": "http://a"})


class LockTest(unittest.TestCase):
    def test_one_agent_per_state_directory(self):
        with tempfile.TemporaryDirectory() as d:
            first = pulse_agent.lock_state(pathlib.Path(d))
            self.assertTrue(first)
            self.assertIsNone(pulse_agent.lock_state(pathlib.Path(d)))  # a second run or once is refused
            first.close()
            again = pulse_agent.lock_state(pathlib.Path(d))
            self.assertTrue(again)
            again.close()


if __name__ == "__main__":
    unittest.main()
