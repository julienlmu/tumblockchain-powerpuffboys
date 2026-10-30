#!/usr/bin/env python3
"""C3 acceptance on Sepolia (docs/SUPPLIERPULSE_PLUS.md §6.3, §7.2): read-only, costs nothing.

Reads the demo orders of §2.5 from the live v2 contract, matched by supplier id (the earliest order of each
supplier, so B2 and dry-run orders do not count), and the agent's cycle log, then checks:
  A 03778796              -> milestone 1 paid by the agent; the supplier's tier has risen
  B 07418033              -> held at the first check (status failed), then refunded by the agent
  C 09729896              -> held with "accounts overdue" (a later refund by the agent is fine)
  D 391200JI69LS8L648F30  -> milestone 1 paid by the agent
  E 52990092KBQJF8QBGJ50  -> held with "LEI renewal overdue" (a later refund by the agent is fine)
  log                     -> at least 10 autonomous cycles
Prints PASS or WAIT (not happened yet) per line and exits 0 once everything passes. Failed order actions,
quarantined orders, RPC read errors and alerts are listed as a note: not part of §6.3, never hidden.

  python3 api3/agent/c3_check.py     # contract and RPCs from the env or api3/agent/.env (default: v2 on Sepolia)
"""
from __future__ import annotations

import sys

import config
from chain import Chain, _int
from journal import Journal
from model import CLOSED, FAIL_BASE, HELD

V2_SEPOLIA = "0xf25Aae1772326C95294D1923399D55c658493DfC"
PUBLIC_RPC = "https://ethereum-sepolia-rpc.publicnode.com"
DEMO = {"A": "03778796", "B": "07418033", "C": "09729896", "D": "391200JI69LS8L648F30", "E": "52990092KBQJF8QBGJ50"}


def read_orders(chain: Chain) -> dict:
    """supplierId -> its earliest order: id, state, paid, milestones paid, last failed rules, supplier tier."""
    found = {}
    for i in range(_int(chain.call("ordersLength")[0])):
        info = chain.call("orderInfo", i)
        sid = str(info[3])
        if sid in found:
            continue
        st, sc = chain.call("orderStatus", i), chain.call("orderSchedule", i)
        key = chain.call("supplierKeyOf", _int(info[2]), sid)[0]
        found[sid] = {"id": i, "state": _int(st[0]), "paid": _int(st[1]), "paid_count": _int(st[3]),
                      "failed": _int(sc[2]), "tier": _int(chain.call("supplierRecord", key)[6])}
    return found


def checks(orders: dict, entries: list) -> list:
    """(description, passed, detail) for the Sepolia acceptance of §6.3."""
    def did(o, actions, outcome):
        return o is not None and any(e.get("orderId") == o["id"] and e.get("action") in actions
                                     and str(e.get("outcome", "")).startswith(outcome) for e in entries)

    def paid_m1(letter):
        o = orders.get(DEMO[letter])
        by_agent = did(o, ("checkAndRelease", "release"), "Paid")
        detail = "no order yet" if o is None else "order %d: %d milestone(s) paid, by the agent: %s" % (
            o["id"], o["paid_count"], "yes" if by_agent else "no")
        return o is not None and o["paid_count"] >= 1 and by_agent, detail

    def held(letter, bits):
        o = orders.get(DEMO[letter])
        ok = o is not None and o["failed"] & bits == bits and o["paid"] == 0 and o["state"] in (HELD, CLOSED)
        return ok, "no order yet" if o is None else "order %d: state %d, failedRules 0x%02x" % (o["id"], o["state"], o["failed"])

    a, b = orders.get(DEMO["A"]), orders.get(DEMO["B"])
    b_refunded = b is not None and b["state"] == CLOSED and did(b, ("refundRemaining",), "Refunded")
    cycles = {e.get("cycle") for e in entries if e.get("cycle") is not None}
    return [
        ("A: milestone 1 paid by the agent",) + paid_m1("A"),
        ("D: milestone 1 paid by the agent",) + paid_m1("D"),
        ("B: held at the first check (status failed)",) + held("B", FAIL_BASE),
        ("B: refunded by the agent after the grace period", b_refunded,
         "no order yet" if b is None else "order %d: state %d" % (b["id"], b["state"])),
        ("C: held with accounts overdue",) + held("C", 0x02),
        ("E: held with LEI renewal overdue",) + held("E", 0x08),
        ("A: the supplier's tier has risen", a is not None and a["tier"] >= 1,
         "no order yet" if a is None else "tier %d (1 Trusted, 2 Premium)" % a["tier"]),
        ("at least 10 autonomous cycles", len(cycles) >= 10, "%d cycles" % len(cycles)),
    ]


def note(entries: list) -> str:
    """Failures in the log, for the record: they do not change the acceptance, and are never left out."""
    failed = [e for e in entries if e.get("outcome") in ("error", "quarantined") and e.get("orderId") is not None]
    read_errors = sum(1 for e in entries if e.get("outcome") == "error" and e.get("orderId") is None)
    alerts = sum(1 for e in entries if e.get("outcome") == "alert")
    last = " (the last at %s)" % failed[-1].get("ts") if failed else ""
    return "failed order actions %d%s, RPC read errors %d, alerts %d" % (len(failed), last, read_errors, alerts)


def main() -> int:
    cfg = config.load(require_chain=False)
    chain = Chain(cfg.contract or V2_SEPOLIA, cfg.rpc_urls or [PUBLIC_RPC])
    entries = Journal(cfg.state_dir / "cycles.jsonl", echo=None).read()
    results = checks(read_orders(chain), entries)
    print("C3 acceptance, contract %s" % chain.contract)
    for name, ok, detail in results:
        print("  %s %-50s %s" % ("PASS" if ok else "WAIT", name, detail))
    print("  note %s" % note(entries))
    passed = all(ok for _, ok, _ in results)
    print("C3 acceptance: %s" % ("PASSED" if passed else "not yet"))
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
