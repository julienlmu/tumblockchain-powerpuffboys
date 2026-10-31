# Demo video: final script and shot list (max 2:30)

One script for the API3 submission video. It merges Orhun's storyboard (`docs/DEMO_IDEAS.md`) and Ulaş's draft (`docs/drafts/video-script.md` on `ulas/plus-story`) and uses only screens that exist on `main` today.

**Rule for every shot:** show the live Sepolia contract `0xf25Aae1772326C95294D1923399D55c658493DfC`, never the local anvil chain, unless the shot says "local". Simulations (`eth_call`, nothing sent) are named as such.

## Before recording (about 10:45–11:00)

1. **Merge `orhun/final-fixes`** into `main` (Julien). It adds `api3/scripts/plus-quick-orders.sh` (orders due in 2 min) and `api3/scripts/judge-tamper.sh` (the one judge command). Without it, skip shot 3's fresh orders and use PO-1001 / PO-1002 instead.
2. **Julien's laptop** records shots 3 and 4: the buyer key and the x402 payer key are in his `api3/.env`.
3. **Agent running** (`api3/agent`, tick 30 s). The Control Room "Agent" screen shows its last action time; check it is recent.
4. **Screen:** browser window at 1280×720, Control Room in **Simple** view, bookmarks bar hidden, macOS "Do Not Disturb" on, one colour theme for all shots.
5. Serve the pages: `python3 -m http.server 8765 --bind 127.0.0.1 --directory demo`, then open `http://localhost:8765/control.html`.
6. Record each shot as a **separate clip** (Cmd+Shift+5 → "Record Selected Portion"). Record the voice afterwards, in one take per shot, and lay it over the clips.

## Shot list and narration

Narration is about 260 words, which is about 1:45 at a calm pace (150 words per minute); the rest is room for on-screen moments. Time it aloud before editing.

| # | Time | Picture | Narration (English) |
|---|---|---|---|
| 1 | 0:00–0:15 | Control Room, **Operations**: "Know why money moves." Caption bottom left: *Insolvency Service, Company Insolvency Statistics, Dec 2025*. | "Last year, one in 190 companies in England and Wales became insolvent. Buyers check a supplier once, at onboarding, then keep paying it. If it fails in between, the next advance is gone." |
| 2 | 0:15–0:35 | The "How it works" diagram from `README.md` (screenshot), then back to Operations. | "SupplierPulse locks the order in a smart contract on Ethereum Sepolia. Before every milestone, our agent buys a signed company record from API3 AirnodeHub, for one cent over x402. The contract checks that record itself, before any money moves." |
| 3 | 0:35–1:05 | Run `api3/scripts/plus-quick-orders.sh` (terminal, 3 s, speed it up), then Operations: **QA** (clean Companies House) gets its permit and is **paid** at its due time; **QB** (Companies House `07418033`, in liquidation) is **held**, with "Refund to buyer". Cut to QA's payment tx on Etherscan. | "Here are two live orders. Supplier A is active in Companies House: the signed record passes, the buyer has approved the milestone, and it is paid the moment it falls due. Supplier B is in liquidation: the contract holds the order, and the remaining money can only go back to the buyer. Here is the payment on Etherscan." |
| 4 | 1:05–1:50 | **Verification lab**, order PO-1001. Upload a record fetched in the last 5 minutes (`api3/scripts/fetch-evidence.sh ch 03778796 record.json`). Press **Fresh, matching record** → permit. Then **Edited value**, **Genuine old record**, **Other company**, **Wrong signing key**, each red. End on **Run the tamper test** → 4/4 rejected. | "Can you fool it? A fresh, matching record passes. Now we change one value and keep the signature: rejected, wrong signer. A genuine record that is too old: rejected, stale. A genuine record for another company: rejected, wrong request. A record signed by a different key: rejected. Each of these is the live contract's own answer." |
| 5 | 1:50–2:10 | **Agent** screen: "Every action, on its own." Scroll the latest actions, open "All transactions". | "Nobody pressed a button for any of this. The agent ran through the night on its own, paying one cent per signed record. If it stops, anyone can make the same call: the contract trusts the signature, not us." |
| 6 | 2:10–2:30 | Terminal: `api3/scripts/judge-tamper.sh` → "All cases behaved as expected". End card: contract address, repo URL, "Built on API3 AirnodeHub". | "Judges can run the whole tamper test with one command. A signature proves what the register said, not that the goods will arrive. That stays the buyer's call. SupplierPulse makes sure you never pay a supplier that has already failed." |

## Timing traps

- **Shot 4 must use a record younger than 5 minutes** (`maxAge` = 300 s). An older record gives `StaleResponse` for every case and hides "wrong signer". Fetch it right before pressing the buttons; if the agent checks PO-1001 in between, fetch again (`docs/LAB_RECORDING.md` on `orhun/lab-interactive`).
- **Shot 3:** QA's first milestone falls due 2 minutes after the orders are created; QB is held at the agent's next tick (≤ 30 s). Start recording Operations right after the script finishes and keep it running for about 3 minutes; the edit cuts it down.
- The valid case (shot 3's payment) is a **sent** transaction; the four rejections in shot 4 are **simulations**. The narration says "the live contract's answer", which is true for both.

## Facts used, with sources

| Claim | Source |
|---|---|
| 1 in 190 companies insolvent in England and Wales (52.5 per 10,000), 2025 | Insolvency Service, *Company Insolvency Statistics December 2025*, via `docs/PITCH_CUSTOMER.md` on `orhun/pitch-customer`. Open the link once before recording. |
| One cent per record over x402 | `api3/x402/airnode-fetch.mjs` (`priceUsd: '0.01'`), `docs/evidence.md` |
| `maxAge` 300 s, contract address | `docs/evidence.md`, "SupplierPulse+ live" |
| Agent acted overnight | Control Room, Agent screen (34 on-chain actions, last 09:28 on 31 Oct 2026) |

Do not say "726,735 companies failed" (most dissolutions are voluntary), and do not show the Cardano jobs as part of this flow (they used a simulated EVM side).

## After recording

1. Edit in CapCut (desktop): cut clips to the table's times, add auto captions, zoom into the error names in shot 4.
2. Export 1080p, check the length is **≤ 2:30**.
3. Upload to YouTube as **unlisted**; put the link in `README.md` and on Devfolio.
