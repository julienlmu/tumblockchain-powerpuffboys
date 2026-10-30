# The SupplierPulse+ agent

The agent runs SupplierPulse+ without a person starting each cycle:
- it decides **which supplier to check and when**;
- it **pays for the signed register record** over x402 ($0.01 in aUSD on Base Sepolia);
- it **acts on chain**: it submits the evidence, pays due milestones, and returns held money to the buyer.

The code is in `api3/agent/` (Python 3.8+, standard library only, Foundry `cast` for chain access). The spec is `docs/SUPPLIERPULSE_PLUS.md` §6.3.

```text
every tick ─▶ read the contract ─▶ plan (pure function) ─▶ act ─▶ log one JSON line per action
              orders, permits,       schedule, budget,       fetch signed record (x402),
              due dates, tiers       retries, quarantine      simulate, then send
```

## Schedule

The agent works in priority order, every tick:

| Priority | When | What the agent does | Costs |
|---|---|---|---|
| 0 | The supplier's register status failed on another order, more recently than this order's last check | `applySupplierFailure`: holds this order too. The failure is already verified on chain, so no new fetch is needed | gas |
| 1 | A held order's refund grace period is over, or the no-data exit applies (an approved milestone is overdue by the grace period without a permit) **and the registry answered "no data" to the agent after the due date** | `refundRemaining`: the remaining balance goes back to the buyer | gas |
| 2 | A milestone is due, the permit is valid and the buyer has approved | `release`: the milestone is paid to the supplier | gas |
| 3 | A milestone is due within the check window and no permit covers the due date. Also the last try before a no-data refund | Fetch a fresh signed record, then `submitEvidence` (before the due date) or `checkAndRelease` (once due) | $0.01 + gas |
| 4 | A supplier was not checked for its tier's interval | Fetch a fresh signed record and submit it to that supplier's order with the nearest due date. A failing supplier is held *before* its next payment is due. Left out: orders whose due milestone waits for the buyer, orders with an action of priority 0–3 this tick, and suppliers with a due-date check (run or waiting) | $0.01 + gas |

**Timing per profile:**

| | Demo | Production |
|---|---|---|
| Tick | 30 s | 5 min |
| Lead time before a due date | 5 min | 1 day |
| Re-check interval: Standard / Trusted / Premium tier | 10 / 30 / 60 min | 1 / 3 / 7 days |

The tier comes from the contract's **verification history**: the supplier's verified register status over time. Only the base status counts, and the history only moves forward, so the agent cannot raise it. A supplier with a long clean history costs fewer paid re-checks.
- **Permits are never extended by the tier.**
- The freshness window (`maxAge`, 300 s) never depends on the tier.
- It is a history of register checks, not a credit score.

**Rules the schedule follows:**
- **One paid check per milestone.** The check window opens at the due date minus the lead time, or minus `permitTtl − 60 s` if the order's permit lifetime is shorter. The permit from that check still covers the due date, so the agent does not fetch again every tick.
- **No paid check while a due milestone waits for the buyer's approval**, neither a due-date check (priority 3) nor monitoring (priority 4). The check before the due date already issued a permit. When the buyer approves while that permit is still valid, the agent pays with `release` and no new check.
- **Refund only on real missing data.** When an approved milestone reaches its no-data exit, the agent refunds only if the registry itself answered "no data" (fetch exit 3) after the due date. If nothing was tried since the due date, it tries at once, skipping the retry backoff that one time. Any other failure (a broken setup, a failed payment, a timeout, an RPC problem) is the agent's problem, not missing data, and must not cost the supplier the order: the agent alerts and keeps to its normal retry schedule. The buyer can always call `refundRemaining` directly.
- **A quarantined order gets no action at all**: no fetch, release, refund or stop.
- **At most one fetch per supplier per tick**, and at most `MAX_FETCHES_PER_TICK` fetches in total.

## Spending limits

| Limit | Demo | Production | Enforced where |
|---|---|---|---|
| Daily budget for paid checks (UTC day) | $1.00 | $5.00 | `policy.py`: no fetch that would exceed it |
| Reserve kept for due-date checks | $0.20 | $1.00 | `policy.py`: monitoring stops at budget minus reserve |
| Fetches per tick | 3 | 10 | `policy.py` |
| Price per payment | at most $0.05, aUSD only | same | the x402 client in `api3/x402/` refuses anything else |
| Gas price | at most 50 gwei | 50 gwei | `executor.py`: no writes above it |
| After a failed payment (for example no aUSD) | all paid checks paused for 15 min | same | `ledger.py` |
| Gas in the agent wallet | at least two writes' worth at the current gas price | same | `executor.py`: otherwise no action, one alert |

**Wasted gas.** Every write is simulated first (`eth_call`) and only sent if the simulation passes, so a record the contract would refuse costs no gas. Every write has a fixed gas limit of 600,000 (unused gas is refunded). With the exact estimate as the limit, a transaction that landed a block later on Sepolia could run out of gas, for example when it also updates the verification history (Batu's finding).

**Free local fetches** (the local test chain) do not count against the budget. A failed fetch that may have been paid (verification failed, timeout, crash) does.

## Failure handling

| What happens | What the agent does |
|---|---|
| No data (fetch exit 3): the Airnode answers with an error, the supplier is unknown, or a field is missing | Retries after 30 s, 2 min, then 8 min. After 3 attempts it logs an **alert** and waits for the next window (30 min in demo). No payment without evidence: the order stays locked. **The only failure that can lead to the no-data refund** |
| The fetch cannot run or has no key (exit 2, for example no `PAYER_PRIVATE_KEY`) | Pauses all paid checks for 15 min and logs an **alert**, like a failed payment. Nothing was paid |
| The x402 payment fails (exit 4) | Pauses all paid checks for 15 min and logs an **alert** |
| The fetched record fails verification (exit 5: wrong signer or request) | Never submits it, logs an **alert** and waits for the next window. The $0.01 counts against the budget: it was paid |
| The fetch times out, crashes or prints no record | Counts the $0.01 (the payment may have settled) and retries with the backoff |
| A paid record cannot be submitted (RPC down, no gas) | Backs off like a failed fetch, instead of buying a new record every tick |
| The contract says `StaleResponse` / `FutureResponse` | Fetches a fresh record after the backoff (counts as an attempt) |
| The contract says `Replayed` / `NotNewer` | Drops the record and backs off; the order already has newer evidence |
| The contract says `WrongRequest` / `WrongSigner` | **Quarantines the order**: no more fetches, releases, refunds or stops for it. This means a configuration mismatch or tampering, so a human looks |
| The contract says `NotActive` / `NotDue` / `NotApproved` / `NotRefundable` / `NoNewerFailure` | Expected. Backs off; the next tick reads the new state |
| The contract says `SupplierFailed` | Expected: the supplier failed on another order. The next tick holds this order (priority 0) instead of paying it |
| Gas price above the cap, or the wallet holds less than two writes' worth of ETH | No action this tick, so nothing is bought that could not be submitted. A low balance logs one **alert** |
| RPC error | Tries the next RPC in `EVM_RPC_URLS`; otherwise retries next tick. A transaction is broadcast once and then followed by its hash, so a failover never sends it twice |
| Crash or restart | The supervised loop restarts it. Spend, retries and quarantine come back from `state.json`. A second agent on the same state directory refuses to start |

## What the agent can never do

- **Approve a milestone.** Only the buyer can do that in the contract.
- **Change who gets paid.** The supplier wallet is fixed at order creation.
- **Pay without fresh, verified evidence.** The contract checks signer, request, freshness and replay, whoever submits.
- **Keep refunded money.** `refundRemaining` always pays the buyer.
- **Leak its key into the log.** Logged errors never contain the agent key, and RPC URLs appear as host names only (a URL can carry an API key).

## Evidence of autonomous cycles

Every action is one JSON line in `api3/agent/state/cycles.jsonl`:

```json
{"ts":"2026-10-31T01:15:02Z","cycle":42,"reason":"milestone due soon","orderId":0,"supplier":"ch:09729896","tier":"Trusted","action":"checkAndRelease","costUsd":0.01,"spentTodayUsd":0.17,"paymentTx":"0x…","outcome":"Paid","tx":"0x…"}
```

`python3 api3/agent/pulse_agent.py report` summarises a run: cycles, actions by outcome, spend per day, tier changes, transactions and alerts.

**Live since Fri 17:03 (v1 hedge):** the agent runs on the deployed v1 contract on Sepolia. Each paid re-check is an x402 payment on Base Sepolia plus a contract transaction; both are linked per cycle in `docs/evidence.md` ("SupplierPulse+ autonomous agent").

*Overnight run on Sepolia: the report and tx links are added on Sat morning (C4).*

## Run it

```sh
cd api3/agent
python3 -m unittest discover -s tests                   # 80 tests, no network
python3 pulse_agent.py run --fake --ticks 45            # whole flow against an in-memory contract, simulated clock
python3 pulse_agent.py report --fake

source ../.local/plus-local.env                         # local test chain (api3/scripts/plus-local.sh)
python3 pulse_agent.py run

AGENT_CONTRACT_VERSION=v1 PULSE_PLUS_ADDRESS=0x91d7dbae109029b2b1245179a68ac362799674d7 python3 pulse_agent.py run
                                                        # hedge: the live v1 contract (status-only fetch via fetch-v1.sh)
cp .env.example .env                                    # Sepolia: fill in the address and keys, then
python3 pulse_agent.py plan                             # what the next tick would do, without acting
./run-forever.sh                                        # supervised loop: restarts after a crash, stops on a
                                                        # config error or a second agent on the same state
python3 pulse_agent.py report --markdown                # every transaction with explorer links, for docs/evidence.md
```

One agent runs per state directory (`state/` for v2, `state/v1/` for v1): a second `run` or `once` on the same one refuses to start, while `plan` and `report` work alongside it. The v1 hedge and the v2 agent can run at the same time.

| Setting | Meaning |
|---|---|
| `AGENT_PROFILE` | `demo` or `prod` (the tables above) |
| `AGENT_CONTRACT_VERSION` | `v2` (SupplierPulsePlus, default) or `v1` (the live v1 contract: no due dates, no tiers, no agent refunds; logs go to `state/v1/`) |
| `PULSE_PLUS_ADDRESS` | the SupplierPulsePlus contract |
| `EVM_RPC_URLS` | comma-separated RPCs, tried in order |
| `AGENT_PRIVATE_KEY` | the agent wallet: gas only. It is not the buyer |
| `PAYER_PRIVATE_KEY` | Base Sepolia wallet with aUSD, used by the fetch script |
| `FETCH_CMD` | `api3/scripts/fetch-evidence.sh` (paid) or `api3/scripts/fetch-local.sh` (local) |
| `DAILY_BUDGET_USD`, `DUE_RESERVE_USD`, `MAX_FETCHES_PER_TICK`, `MAX_GAS_PRICE_GWEI`, `TICK_SECONDS`, `DUE_LEAD_SECONDS`, `MONITOR_SECONDS_STANDARD` / `_TRUSTED` / `_PREMIUM`, `MAX_FETCH_ATTEMPTS` | override the profile |
