#!/usr/bin/env python3
"""C2 integration check (docs/SUPPLIERPULSE_PLUS.md §7.1): contract, local data and agent, end to end.

Starts the local test chain with api3/scripts/plus-local.sh (Orhun), runs the agent against it in real
time with the local fetch (Emre's api3/scripts/fetch-local.sh by default), and checks the outcome of
the six local orders of §4.8:
  0  Companies House clean        -> milestone 0 paid
  1  Companies House liquidation  -> held (status + accounts overdue), refunded after the grace period
  2  GLEIF clean                  -> milestone 0 paid
  3  GLEIF lapsed                 -> held (LEI renewal overdue), refunded
  4  same supplier as order 1     -> held by the supplier-wide stop without a fetch, refunded
  5  no data                      -> refunded through the no-data exit
plus: supplier 01234567 reaches Trusted, and nothing is quarantined or errors.
It stops as soon as every check passes (about 4 minutes) and exits 0, or 1 on timeout.

  python3 api3/agent/c2_check.py                 # full run (needs anvil, forge, cast, jq, node)
  python3 api3/agent/c2_check.py --skip-setup    # reuse a chain set up by plus-local.sh moments ago
  python3 api3/agent/c2_check.py --fake          # the same checks against the in-memory contract
"""
from __future__ import annotations

import argparse
import os
import shlex
import shutil
import subprocess
import sys
import time
from pathlib import Path

import config
import fakes
from chain import Chain, _int
from executor import Executor
from evidence import Fetcher
from journal import Journal
from ledger import Ledger
from model import CLOSED

ENV_FILE = config.REPO_ROOT / "api3" / ".local" / "plus-local.env"
STATE_DIR = config.REPO_ROOT / "api3" / ".local" / "c2-agent"


class ChainProbe:
    """Reads the outcome from the local contract."""

    def __init__(self, chain: Chain):
        self.chain = chain

    def order(self, i: int) -> dict:
        st, sc = self.chain.call("orderStatus", i), self.chain.call("orderSchedule", i)
        return {"state": _int(st[0]), "paid": _int(st[1]), "failed": _int(sc[2])}

    def tier(self, source: int, supplier_id: str) -> int:
        key = self.chain.call("supplierKeyOf", source, supplier_id)[0]
        return _int(self.chain.call("supplierRecord", key)[6])


class FakeProbe:
    def __init__(self, chain: fakes.FakeChain):
        self.chain = chain

    def order(self, i: int) -> dict:
        o = self.chain.orders[i]
        return {"state": o["state"], "paid": o["paid"], "failed": o["last_failed"]}

    def tier(self, source: int, supplier_id: str) -> int:
        return self.chain.suppliers[fakes.fake_supplier_key(source, supplier_id)]["tier"]


def checks(probe, entries: list) -> list:
    """(description, passed, detail) for every expected outcome of §7.1."""
    o = {i: probe.order(i) for i in range(6)}

    def of(i):
        return [e for e in entries if e.get("orderId") == i]

    fetched_4 = [e for e in of(4) if e.get("action") in ("fetch", "submitEvidence", "checkAndRelease")]
    stop_4 = [e for e in of(4) if e.get("action") == "applySupplierFailure" and str(e.get("outcome", "")).startswith("Held")]
    no_data_5 = [e for e in of(5) if e.get("action") == "refundRemaining" and e.get("noDataExit")]
    bad = [e for e in entries if e.get("outcome") in ("quarantined", "error")
           or (e.get("outcome") == "alert" and e.get("orderId") != 5)]
    tier = probe.tier(0, "01234567")
    return [
        ("order 0: Companies House clean, milestone 0 paid", o[0]["paid"] > 0, "paid %d" % o[0]["paid"]),
        ("order 1: liquidation held (status + accounts overdue), refunded",
         o[1]["state"] == CLOSED and o[1]["paid"] == 0 and o[1]["failed"] == 0x82,
         "state %d, failedRules 0x%02x" % (o[1]["state"], o[1]["failed"])),
        ("order 2: GLEIF clean, milestone 0 paid", o[2]["paid"] > 0, "paid %d" % o[2]["paid"]),
        ("order 3: LEI renewal overdue held, refunded",
         o[3]["state"] == CLOSED and o[3]["paid"] == 0 and o[3]["failed"] == 0x08,
         "state %d, failedRules 0x%02x" % (o[3]["state"], o[3]["failed"])),
        ("order 4: supplier-wide stop without a fetch, refunded",
         bool(stop_4) and not fetched_4 and o[4]["state"] == CLOSED,
         "stop %s, own fetches %d, state %d" % (bool(stop_4), len(fetched_4), o[4]["state"])),
        ("order 5: no data, refunded through the no-data exit", bool(no_data_5) and o[5]["state"] == CLOSED,
         "no-data exit %s, state %d" % (bool(no_data_5), o[5]["state"])),
        ("supplier 01234567 reached Trusted", tier >= 1, "tier %d" % tier),
        ("nothing quarantined, no errors, alerts only for the no-data supplier", not bad,
         "; ".join("order %s %s %s" % (e.get("orderId"), e.get("outcome"), e.get("error", ""))[:120] for e in bad[:3]) or "clean"),
    ]


def report(results: list) -> bool:
    for name, ok, detail in results:
        print("  %s %-68s %s" % ("PASS" if ok else "FAIL", name, detail))
    return all(ok for _, ok, _ in results)


def read_env_file(path: Path) -> dict:
    env = {}
    for line in path.read_text().splitlines():
        line = line.strip()
        if line.startswith("export "):
            line = line[len("export "):]
        if "=" in line and not line.startswith("#"):
            key, value = line.split("=", 1)
            env[key.strip()] = value.strip()
    return env


def run_fake(cfg: config.Config, minutes: float) -> bool:
    chain, fetcher = fakes.local_world()
    journal = Journal(cfg.state_dir / "cycles.jsonl", echo=None)
    agent = Executor(chain, fetcher, Ledger(cfg.state_dir / "state.json"), journal, cfg)
    probe = FakeProbe(chain)
    for _ in range(int(minutes * 60 / cfg.tick_seconds)):
        agent.tick()
        chain.advance(cfg.tick_seconds)
        if all(ok for _, ok, _ in checks(probe, journal.read())):
            break
    print("simulated %d s" % (chain.now() - 1_800_000_000))
    return report(checks(probe, journal.read()))


def run_real(cfg: config.Config, minutes: float, skip_setup: bool, fetch_cmd: str) -> bool:
    env = dict(os.environ)
    env["PATH"] = "%s:%s" % (Path.home() / ".foundry" / "bin", env.get("PATH", ""))
    if not skip_setup:
        script = config.REPO_ROOT / "api3" / "scripts" / "plus-local.sh"
        if not script.exists():
            sys.exit("missing %s (Orhun's branch is not merged here yet)" % script)
        print("setting up the local test chain (plus-local.sh) ...")
        subprocess.run(["bash", str(script)], cwd=str(config.REPO_ROOT), env=env, check=True)
    if not ENV_FILE.exists():
        sys.exit("missing %s: run api3/scripts/plus-local.sh first" % ENV_FILE)
    local = read_env_file(ENV_FILE)
    os.environ.update(local)  # the fetch command needs LOCAL_CH_KEY / LOCAL_GLEIF_KEY
    os.environ["PATH"] = env["PATH"]
    cmd = shlex.split(fetch_cmd or local.get("FETCH_CMD", "api3/scripts/fetch-local.sh"))
    if not (config.REPO_ROOT / cmd[0]).exists() and not shutil.which(cmd[0]) and not Path(cmd[0]).exists():
        sys.exit("missing fetch command %s (Emre's branch is not merged here yet)" % cmd[0])

    chain = Chain(local["PULSE_PLUS_ADDRESS"], [local["EVM_RPC_URL"]], local["AGENT_PRIVATE_KEY"])
    count = _int(chain.call("ordersLength")[0])
    record = chain.call("supplierRecord", "0x" + "00" * 32)
    if count != 6 or len(record) != 7:
        sys.exit("the local chain is not spec v1.1: %d orders (want 6), supplierRecord has %d fields (want 7)"
                 % (count, len(record)))
    cfg.contract, cfg.rpc_urls, cfg.agent_key, cfg.fetch_cmd = chain.contract, chain.rpc_urls, local["AGENT_PRIVATE_KEY"], tuple(cmd)
    journal = Journal(cfg.state_dir / "cycles.jsonl", echo=print)
    agent = Executor(chain, Fetcher(cmd, cwd=config.REPO_ROOT), Ledger(cfg.state_dir / "state.json"), journal, cfg)
    probe = ChainProbe(chain)
    print("contract %s, agent %s, fetch %s" % (chain.contract, chain.address, " ".join(cmd)))
    end = time.time() + minutes * 60
    rpc = local["EVM_RPC_URL"]
    while time.time() < end:
        # anvil only mines on transactions, so after idle time its block time lags the clock and a fresh
        # record would simulate as FutureResponse (Batu's finding). Mining an empty block brings it to now.
        subprocess.run(["cast", "rpc", "--rpc-url", rpc, "evm_mine"], env=env, capture_output=True)
        agent.tick()
        if all(ok for _, ok, _ in checks(probe, journal.read())):
            break
        time.sleep(cfg.tick_seconds)
    print("\nresult after %d s:" % (minutes * 60 - max(0, end - time.time())))
    ok = report(checks(probe, journal.read()))
    print("agent log: %s (anvil keeps running on %s)" % (journal.path, local["EVM_RPC_URL"]))
    return ok


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--minutes", type=float, default=8.0, help="give up after this long (default 8)")
    ap.add_argument("--skip-setup", action="store_true", help="do not run plus-local.sh")
    ap.add_argument("--fetch-cmd", default="", help="override FETCH_CMD from plus-local.env")
    ap.add_argument("--fake", action="store_true", help="run the checks against the in-memory contract")
    args = ap.parse_args()

    # fast local timing: 10 s ticks, re-check every 1/2/5 min by tier (the local contract counts every 60 s)
    cfg = config.Config(profile="demo", contract="", rpc_urls=[], fetch_cost_usd=0.0, state_dir=STATE_DIR,
                        tick_seconds=10, due_lead_seconds=300, monitor_seconds=(60, 120, 300),
                        max_fetches_per_tick=6)
    shutil.rmtree(cfg.state_dir, ignore_errors=True)
    ok = run_fake(cfg, args.minutes) if args.fake else run_real(cfg, args.minutes, args.skip_setup, args.fetch_cmd)
    print("C2 check: %s" % ("PASSED" if ok else "FAILED"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
