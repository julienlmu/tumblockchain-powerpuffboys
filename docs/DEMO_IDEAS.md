# Demo video idea (max 2.5 min)

An idea for the video, not decided yet. The happy path comes first, the attacks after it.

## Before filming

1. About 5 minutes before recording, open fresh orders on the live v2 (Sepolia) that are due in 2 minutes instead of 20 to 30:
   ```
   api3/scripts/plus-quick-orders.sh
   ```
   It prints the order ids (QA clean Companies House, QB liquidation, QD clean GLEIF) and a timeline. Costs 0.002 ETH from the buyer and $0.01 aUSD per agent check. Needs `EVM_RPC_URL`, `BUYER_PRIVATE_KEY`, `PULSE_PLUS_ADDRESS`, `DEMO_SUPPLIER_1`, `DEMO_SUPPLIER_2`.
2. Keep the agent running so it checks and pays QA and QD once due, and holds QB at its first check.
3. Record the tamper test with `api3/scripts/judge-tamper.sh` (local anvil, no keys, a few seconds). Record four terminals side by side, one case each, so the edit can zoom into each.

`plus-quick-orders.sh` and `judge-tamper.sh` are on `orhun/final-fixes` until Julien merges it (see `docs/TODO.md`).

## Storyboard

| Time | Shot | What the viewer sees |
|---|---|---|
| 0:00–0:20 | Problem and solution | One sentence each: a buyer pays a supplier in advance; if the supplier goes under, the money is gone. SupplierPulse+ pays each milestone only against a fresh, signed registry record from API3. |
| 0:20–1:00 | Happy path (the most important part) | Dashboard: QA is paid against a valid API3-signed Companies House record. QB's supplier is in liquidation: the payment stops and the order is held; the buyer can refund. |
| 1:00–1:10 | Four terminals at once | All four attacks run side by side, each ends in a red REJECTED. |
| 1:10–2:00 | Zoom into each, about 12 s | One label line and the contract's error name on screen (see the table below). |
| 2:00–2:30 | "Judges can try it" | The single command `api3/scripts/judge-tamper.sh`, then the contract on Etherscan: `0xf25Aae1772326C95294D1923399D55c658493DfC`. |

## The four attacks (names as `judge-tamper.sh` prints them)

| Case | On-screen label | Contract error |
|---|---|---|
| (a) | One value edited (e.g. status "active" → "liquidation"), signature unchanged | `WrongSigner` |
| (b) | Too old (timestamp 1 h back) | `StaleResponse` |
| (c) | Another company's request | `WrongRequest` |
| (d) | Signed by another key | `WrongSigner` |

Extra, if there is time: the valid record sent a second time → `Replayed`.

Use these names in the video. "Wrong amount" is not a separate check in the contract, so don't show it as an attack.
