#!/usr/bin/env python3
"""SupplierPulse+ agent: checks suppliers on schedule, pays for signed evidence, acts on chain.

Commands:
  run      loop forever, one tick every TICK_SECONDS (--ticks N to stop after N)
  once     one tick
  plan     show what the next tick would do, without acting or paying
  report   summary of the cycle log (cycles, actions, spend, tier changes)
Add --fake to run against the in-memory contract and registry (simulated clock), e.g.
  python3 api3/agent/pulse_agent.py run --fake --ticks 40
Settings: api3/agent/.env.example and docs/agent.md.
"""
from __future__ import annotations

import argparse
import sys
import time
from urllib.parse import urlparse

import config
from chain import Chain
from chain_v1 import ChainV1
from evidence import Fetcher
from executor import Executor
from journal import Journal, report
from ledger import Ledger
from policy import plan


def build(args):
    if args.fake:
        import fakes

        cfg = config.load(profile=args.profile, require_chain=False)
        cfg.state_dir = cfg.state_dir / "fake"
        cfg.fetch_cost_usd = 0.01
        chain, fetcher = fakes.local_world()
    else:
        cfg = config.load(profile=args.profile)
        chain = (ChainV1 if cfg.contract_version == "v1" else Chain)(cfg.contract, cfg.rpc_urls, cfg.agent_key)
        fetcher = Fetcher(cfg.fetch_cmd, cwd=config.REPO_ROOT)
    ledger = Ledger(cfg.state_dir / "state.json")
    journal = Journal(cfg.state_dir / "cycles.jsonl", echo=None if args.quiet else print)
    return cfg, chain, Executor(chain, fetcher, ledger, journal, cfg)


def banner(cfg, chain, fake: bool) -> None:
    hosts = ", ".join(urlparse(u).netloc or u for u in cfg.rpc_urls) or "-"  # never print full URLs (may hold keys)
    target = "FAKE chain and registry" if fake else "%s contract %s" % (cfg.contract_version, cfg.contract)
    print("SupplierPulse+ agent | profile %s | %s" % (cfg.profile, target))
    if not fake:
        print("agent %s | rpc %s | fetch %s" % (chain.address, hosts, " ".join(cfg.fetch_cmd)))
    print("tick %ss | due lead %ss | re-check %s s by tier | budget $%.2f/day (reserve $%.2f) | max %d fetches/tick"
          % (cfg.tick_seconds, cfg.due_lead_seconds, "/".join(str(s) for s in cfg.monitor_seconds),
             cfg.daily_budget_usd, cfg.due_reserve_usd, cfg.max_fetches_per_tick))


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("command", choices=["run", "once", "plan", "report"])
    ap.add_argument("--fake", action="store_true", help="in-memory contract and registry, simulated clock")
    ap.add_argument("--profile", choices=sorted(config.PROFILES), help="default: AGENT_PROFILE or demo")
    ap.add_argument("--ticks", type=int, default=0, help="run: stop after N ticks (0 = forever)")
    ap.add_argument("--quiet", action="store_true", help="log to the file only")
    args = ap.parse_args(argv)

    if args.command == "report":
        cfg = config.load(profile=args.profile, require_chain=False)
        state_dir = cfg.state_dir / "fake" if args.fake else cfg.state_dir
        print(report(Journal(state_dir / "cycles.jsonl").read(), Ledger(state_dir / "state.json").data["spend"]))
        return 0

    try:
        cfg, chain, executor = build(args)
    except ValueError as e:
        print("config error: %s" % e, file=sys.stderr)
        return 2

    if args.command == "plan":
        p = plan(chain.snapshot(), executor.ledger, cfg)
        for a in p.actions:
            print("DO   %-10s order %s %s (%s)" % (a.kind, a.order_id, a.supplier, a.reason))
        for a, reason in p.skipped:
            print("SKIP %-10s order %s %s: %s" % (a.kind, a.order_id, a.supplier, reason))
        if not p.actions and not p.skipped:
            print("nothing to do")
        return 0

    banner(cfg, chain, args.fake)
    ticks = 1 if args.command == "once" else args.ticks
    done = 0
    try:
        while True:
            executor.tick()
            done += 1
            if ticks and done >= ticks:
                break
            if args.fake:
                chain.advance(cfg.tick_seconds)
            else:
                time.sleep(cfg.tick_seconds)
    except KeyboardInterrupt:
        print("stopped after %d ticks" % done)
    return 0


if __name__ == "__main__":
    sys.exit(main())
