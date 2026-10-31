# Recording the Verification lab (Control Room)

How to film the "edit the signed data yourself" scene in `demo/control.html#lab` on the live Sepolia contract, and why the timing matters.

## Why the record must be fresh

The contract checks a record in a fixed order and stops at the first failure (`_verify` in `api3/src/SupplierPulsePlus.sol`):

active order → request → time (`maxAge` = 300 s) → not used before → newer than the last check → signer → order rules

The time check comes **before** the signer check. So:

| When | What you do | Contract answer |
|---|---|---|
| 10:00 | `fetch-evidence.sh` returns a record signed at 10:00 | – |
| 10:02 | Ask with the untouched record | Simulation: would issue a permit |
| 10:02 | Change `active` → `liquidation`, ask again | **`WrongSigner`** (the scene we want) |
| 10:07 | Edit the same record again | **`StaleResponse`**: the record is older than 300 s, the signer is never checked |

`StaleResponse` is correct, but it hides the message "you changed the data, the signature no longer matches". Use the record within 5 minutes; if time runs out, fetch a new one ($0.01).

## Steps

1. Start the screen recording and open `http://localhost:8765/control.html#lab`, order **PO-1001** (Companies House `03778796`, active).
2. Only then fetch the record ($0.01 test aUSD over x402 on Base Sepolia; needs `PAYER_PRIVATE_KEY` in `api3/.env`):
   ```sh
   api3/scripts/fetch-evidence.sh ch 03778796 record.json
   ```
3. Paste `record.json` under **Signed record**.
4. In **Edit the signed data yourself**: press **Ask the contract: untouched record** → "Simulation: would issue a permit", every check passed.
5. Change `"active"` to `"liquidation"`, ask again → `WrongSigner`; "Where the contract stopped" shows the signer check in red and the rules check as not reached.
6. Optional: **Run the tamper test** → "4/4 attacks rejected". All five are `eth_call` simulations, nothing is sent.

The record must belong to the order's company, be unused, and be newer than the agent's last check of that order. If the agent checks PO-1001 between steps 2 and 4, fetch a new record.

## Test run, 31 Oct 08:35 CET (all free, no paid call)

| What | Result |
|---|---|
| `forge test` | 115/115 |
| Agent `pytest` | 86 passed, 1 skipped |
| `x402/test-requests.mjs` | 11/11 |
| Local anvil, tamper test #0 (Companies House) and #2 (GLEIF) | 4/4 each, valid record accepted |
| Local editor (GLEIF) | untouched → would issue a permit; `ACTIVE` → `INACTIVE` → `WrongSigner`; Reset works |
| Local replay (Complex view) | sent once (block 72), then `Replayed` |
| Live Sepolia, PO-1001 | contract found by itself; "Genuine old record" → `StaleResponse`, "Other company" → `WrongRequest`; without a record the tamper test and editor ask for one |
| Pages | Operations, Agent, Judge kit, Settings, `index.html`, `simple.html`: no console errors |

Not yet run: the live edit scene with a fresh record (needs the paid fetch above).
