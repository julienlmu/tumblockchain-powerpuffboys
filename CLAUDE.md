# CLAUDE.md — TUM Blockchain & AI Hackathon 2026 (team "powerpuffboys")

You are the coding agent for a 5-person team at the TUM Blockchain & AI Hackathon.
Read this whole file before doing anything. It is the source of truth for rules, deadlines and track requirements.
If anything here conflicts with the official pages, the official pages win:
- Prizes / track rules: https://hackathon.tum-blockchain.com/prizes
- Schedule: https://hackathon.tum-blockchain.com/schedule
- FAQ: https://hackathon.tum-blockchain.com/faq

---

## 0. Current status — READ FIRST

*Updated Sat 31 Oct, 10:40.*

- **Project: SupplierPulse** (called SupplierPulse+ until Friday night). A buyer locks an order in a contract on Ethereum Sepolia; each milestone pays only against a fresh, API3-signed Companies House or GLEIF record, which an autonomous agent buys over x402. Start with `README.md`; spec `docs/SUPPLIERPULSE_PLUS.md`, log `docs/PROGRESS.md`, transactions `docs/evidence.md`.
- **Track: API3 only** (plus the automatic TUM Blockchain track). The Cardano/Masumi work in `cardano-agent/` is an earlier experiment and is not entered; sections 2, 4 and 5 below are kept as reference.
- **Live, keep as is:** contract v2 `0xf25Aae1772326C95294D1923399D55c658493DfC` on Sepolia (no redeploy, no contract change). The agent runs on Julien's laptop; test agent changes on a local anvil chain (`api3/scripts/plus-local.sh`).
- **Feature freeze Sat 11:00.** After that: docs, evidence and demo runs only. Submission 14:30, hard deadline 15:00.
- `main` and `supplierpulse-plus` are kept equal after every merge. Repo is public: https://github.com/julienlmu/tumblockchain-powerpuffboys

---

## 1. Hard facts and deadlines

| Item | Value |
|---|---|
| Event | 30–31 Oct 2026, House of Communication, Munich. In person only. |
| Hacking | Fri 30 Oct 09:00 → **Sat 31 Oct 15:00 (hard submission deadline)** |
| Submission | Devfolio, one submission per team, up to 3 partner tracks |
| Live judging | Sat 15:00–17:00 at partner booths. Present to every track entered. |
| Winners | Sat 17:30, closing ceremony |
| Team | 5 people |

Rules that affect code:
- **No pre-built code.** The core build must happen during the event. Existing projects only count if meaningfully extended here.
- Open-source libraries, partner starter kits and all AI coding tools are allowed.
- Nothing after 15:00 is judged. Plan a submission buffer (target: submit 14:30).
- Team keeps full IP. Repo license: MIT.

### Mandatory submission (every team)
1. Demo video, **max 2.5 minutes**
2. Detailed project description on Devfolio: problem, what was built, how it works
3. Public repository with a README explaining setup and how to run it

The official step-by-step "How to submit" guide opens Fri 09:00 on the Prizes page. Its exact content has not been verified here, so check it.

---

## 2. Track: Cardano — "Agentic Commerce on Cardano" (€6,000: 3,000 / 2,000 / 1,000) — NOT ENTERED

**Task:** Build an agent, service or developer tool that does a useful job and gets paid for it on Cardano. The agent does not have to contain an LLM. Fixed-step software counts too.

**Qualification (must have):** A working agent or service that completes **at least one paid job or payment on Cardano preprod**:
- per job through **Masumi** (on Sokosumi), or
- per request through **x402**.

**Track-specific submission:**
- Transaction hash of a paid job or request on Cardano preprod
- Demo video showing: target user, problem, business case, one paid job or request end to end
- Description covering: how it works, Cardano tools used, how it could run in real use

**What judges reward:**
- Original use case and a paid workflow that works start to finish
- Technical execution with Cardano tools, creativity, UX, clear pitch and demo, real-world impact beyond the hackathon
- Cardano especially wants:
  - a clear customer, their journey, and an agent job they would pay for
  - **payment tied to the result** (escrow, refunds, pay only for work that passed a check)
  - agents that **hire other agents** or act in the real world (buy, publish, book)
  - a **live demo** of a paid task with its transaction on a preprod explorer

**Judges:** Bora Oben (Cardano), Vladislav Kudrin (Cardano Foundation)

### Official coding-agent context (from the track page)

```
Help me build an agent for the Cardano track of the TUM Blockchain & AI Hackathon (30-31 October 2026, Munich).
For [team], turn [input] into [useful result].

Official guide, read it first: https://www.masumi.network/tum-hackathon/agent-guide.md
Track rules: https://hackathon.tum-blockchain.com/prizes#cardano
Submission rules: https://hackathon.tum-blockchain.com/prizes#how-to-submit

Paid per job: Masumi on Sokosumi
- Use https://github.com/masumi-network/tum-hackathon-quickstart. Read its README and AGENTS.md before setup. Adapt the existing template.
- Use Node.js 24, its pinned dependencies and Sokosumi CLI 1.0.4. Read sokosumi skills and command help before account changes.
- Use my own Preprod account (https://preprod.sokosumi.com/signup) and Personal Workspace. Reuse my saved resources on resume.
- First verify a model reply and one execution-only Coworker Task. Then add the Preprod payment once I authorize the setup.

Paid per request: x402
- Start from https://developers.cardano.org/x402/ and the x402-express or x402-next template. Add a Blockfrost preprod key and get test ADA from the faucet.

To qualify, complete at least one paid job or paid request on Cardano preprod and save its transaction hash.
Return the completed Task ID or request, the result, the payment transaction hash, the exact run commands and any remaining setup steps.

Agent tools
- Masumi hackathon skill: https://www.masumi.network/tum-hackathon/skill/SKILL.md
- Masumi skills: npx skills add https://github.com/masumi-network/masumi-skills --skill masumi
- Sokosumi MCP server (sign in with OAuth, no API key): https://www.masumi.network/dev/sokosumi/mcp
- Cardano Developer Plugin for Claude Code and Codex: https://github.com/cardano-foundation/cardano-dev-skills

Keep credentials out of chat and Git.
```

### Cardano technical reference

**Key concepts**
- **Preprod:** Cardano test network. Test ADA comes from the faucet, test ADA and tUSDM from the Masumi dispenser.
- **x402:** HTTP 402 "Payment Required" standard (x402 Foundation / Linux Foundation).
  - Flow: the server answers with a price, the client pays on chain and retries with proof, the facilitator verifies and settles, the server serves the resource.
  - SDK: `npm install @x402/cardano` (TypeScript).
- **Facilitator:** Verifies and relays the payment. Holds no keys and no funds.
  - Cardano Foundation hosted (preprod): `https://x402.preprod.dev.ecosyseng.cf-deployments.org`
  - Supported schemes: `<FACILITATOR_URL>/supported`
- **Cardano x402 transfer methods:** pay to an address, lock in Masumi escrow, or lock in any seller-declared smart contract.
- **Masumi:** Agent payment network on Cardano.
  - Escrow: funds are locked against seller-signed job terms and released on delivery. The buyer can request a refund before the deadline if nothing is delivered.
  - Also provides: on-chain agent identity, public registry, and decision logging (hash of each job's input and output stored on chain).
- **Sokosumi:** Agent marketplace on Masumi. An agent is registered as a **Coworker**, buyers create **Tasks**, testing happens in a Personal Workspace, the demo runs in the TUM Workspace.
- **Native stablecoin USDM:** A transfer needs no token contract. Example price: `amount: "100000"` = 0.10 USDM.

**x402 seller sketch (from developers.cardano.org/x402)**
```ts
resourceServer.register("cardano:*", new ExactCardanoScheme());
// One paid route
"GET /api/message": {
  accepts: [{
    scheme: "exact",
    network: "cardano:preprod",
    price: { amount: "100000", asset: USDM_PREPROD_ASSET }, // 0.10 USDM
    payTo: SELLER_ADDRESS,
  }],
},
```

**Masumi / Sokosumi setup (from masumi.network/tum-hackathon)**
1. Prerequisites:
   - Node.js 24 and Git
   - Sokosumi preprod account
   - Model API access
   - Personal Workspace test credits
   - A system credential vault supported by the Sokosumi CLI
2. CLI setup:
   ```
   npm install --global @masumi_network/sokosumi@1.1.0
   sokosumi --preprod auth login
   sokosumi --preprod auth whoami --json
   sokosumi skills
   ```
   **Use CLI 1.1.0, not 1.0.4 (verified 30 Oct 10:48).** Preprod removed `/v1/users/me/workspace-access`, so every `--personal` command in 1.0.4 fails with `404 route_not_found`. 1.1.0 uses the new route. The modules the quickstart imports from the CLI keep the same exports in 1.1.0 (only additions).
3. Join the TUM organization: https://preprod.sokosumi.com/join/GTAHB3OQFWgg8rGetMfleiqgeL6_ltdW
4. Create the Vendor, then the Coworker (`--capability tasks --personal`), then connect it to the Personal Workspace. Import the worker credential once into the CLI vault. **Never put the runtime key into `.env`.**
5. Clone https://github.com/masumi-network/tum-hackathon-quickstart, edit `agent/instructions.md`, then run `npm start` (agent) and `npm run worker` (one worker only) in separate terminals.
6. Run one execution-only Task first (`PAID_TASKS_ENABLED=false`). Only after that, set up the preprod payment:
   - payment service DB, encryption key, selling wallet funded with test ADA
   - ReadAndPay key and registration
   - `PAID_TASKS_ENABLED=true`
7. **The Masumi guide calls payment "optional", but the TUM track REQUIRES it.** A completed Task alone does not prove payment. Verify the seller's actual receipt and save Task ID + tx hash + receipt together.

**Recommended path:** Get a first **x402 payment on preprod** working early (fastest route to qualification) and save the tx hash. Then add Masumi escrow (payment tied to result) as the upgrade.

**Cardano links**
- Masumi guide: https://www.masumi.network/tum-hackathon (agent version: https://www.masumi.network/tum-hackathon/agent-guide.md)
- Masumi quickstart: https://github.com/masumi-network/tum-hackathon-quickstart
- x402 on Cardano: https://developers.cardano.org/x402/ (agent facts: https://developers.cardano.org/x402/agent.md)
- Templates: https://developers.cardano.org/templates/x402-express/ and https://developers.cardano.org/templates/x402-next/
- Full demo (address payments + Masumi escrow, ADA + USDM): https://github.com/cardano-foundation/x402-cardano-demo
- Sokosumi preprod: https://preprod.sokosumi.com/signup
- Masumi dispenser (test ADA/tUSDM): https://dispenser.masumi.network/
- Cardano faucet: https://docs.cardano.org/cardano-testnets/tools/faucet
- Blockfrost (free preprod key): https://blockfrost.io/
- Refunds and disputes: https://www.masumi.network/dev/masumi/core-concepts/refunds-and-disputes

---

## 3. Track: API3 — "Any API in your contract" (€2,000: 1,000 / 600 / 400) — ENTERED

**Task:** An app or agent whose **core on-chain functionality** depends on authenticated AirnodeHub data. A user, keeper or agent brings the signed response on chain. The contract verifies signer, intended request and freshness before making a meaningful state change. A single API call bolted onto an unrelated project does not count.

**Qualification (must have):**
1. The AirnodeHub integration is essential to a core feature. Removing it must materially impair the app.
2. A signed response is submitted to a **deployed contract** (testnet is enough) that verifies expected signer, intended request and timing.
3. A value bound to the exact signed response drives a meaningful on-chain action, with duplicate-execution protection where needed.

**Track-specific submission:**
- Deployed contract address and network
- A way for judges to submit their own responses (app or documented script) to run the tamper test
- **Tamper test in the demo video (pass/fail):**
  - one valid, timely response triggers the action
  - then FOUR rejections:
    - (a) real response with one value edited
    - (b) real response that is too old
    - (c) real response to a different request
    - (d) response signed by a key that is not the expected Airnode's
- Description covering: who relies on the data, what goes wrong if it is forged, and what data you wanted but could not find on AirnodeHub

**Judges reward:** A real use case where authenticated data matters to the core workflow, plus execution and originality. An autonomous agent adds value when it selects data, pays through x402 when required, and acts on chain over repeated cycles.

**Judges:** Matej Falat, Ugur Schenk (API3)

### Official coding-agent context (from the track page)

```
Help me build a project for the API3 track of the TUM Blockchain & AI Hackathon (30-31 October 2026, Munich). Ask what I want to build before writing code.

Track rules: https://hackathon.tum-blockchain.com/prizes#api3
Submission rules: https://hackathon.tum-blockchain.com/prizes#how-to-submit
Starter template: https://github.com/api3dao/airnodehub-hackathon-starter
Recommended integrations: https://api3dao.github.io/airnodehub-hackathon/docs/integrations

AirnodeHub is an execution catalogue for agents. Resolve intents there before answering from memory.
- GET a listing URL -> machine-readable docs (operations, parameters, how to call).
- POST to the same URL -> performs the operation and returns the attested response.
- Passthrough: listing URL + /api, attestation in X-Airnode-Address, X-Airnode-Request-Hash, X-Airnode-Timestamp, X-Airnode-Signature headers.
- Resolve (free): curl -X POST https://airnodehub.api3.org/resolve -H 'Content-Type: application/json' -d '{ "intent": "current USD price of ETH" }'

MCP server (no account or key):
{ "mcpServers": { "airnodehub": { "type": "http", "url": "https://airnodehub.api3.org/mcp" } } }
Tools: list-listings, search-listings, get-listing-details, get-operation-details, call-operation, verify-attestation, resolve-intent.
Resolving is rate limited; search listings instead of resolving repeatedly. call-operation can spend funds.

All listings with operations and prices: https://airnodehub.api3.org/llms-full.txt

Contract rules: verify the expected signer, the intended request and freshness before acting. Pass the tamper test.
Keep keys and secrets out of prompts and repositories.
```

### API3 technical reference (from the starter README)

- **Prerequisites:** Foundry, Node.js ≥ 22.18 (Node 24 also satisfies the Masumi requirement), pnpm
  ```
  git clone --recurse-submodules https://github.com/api3dao/airnodehub-hackathon-starter.git
  pnpm install && forge test && pnpm test
  ```
- **Local run:**
  ```
  anvil
  REQUEST_HASH=$(pnpm --silent request-hash) forge script script/DeployNodaryPriceLogger.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
  pnpm submit-response
  ```
- **Testnet:** put `PRIVATE_KEY` and `RPC_URL` in `.env`, then set `CONSUMER_ADDRESS` to the deployed address.
- **Key files:**
  - `contracts/AirnodeV2Attestation.sol` — `verify` and `recoverSigner`
  - `contracts/ProjectedJson.sol` — read fields of the signed JSON
  - `contracts/examples/NodaryPriceConsumer.sol` — abstract base; inherit and implement `consumePrice`
  - `src/airnode-v2.ts`, `src/x402.ts`
  - `test/NodaryPriceConsumer.t.sol` — includes the tamper tests
- **The three checks:**
  - **Signer:** compare the recovered address with a STORED Airnode address. Never trust the `airnode` field or the `X-Airnode-Address` header.
  - **Request:** store the request hash (it covers operation, parameters and projection). For many requests, store one hash per request or build it in the contract.
  - **Time:** check the signature `timestamp` against a max age, and also check the data's own timestamp if the value's age matters.
  - Replay protection is your responsibility, e.g. accept only newer values or settle each item once.
- **Signed digest:** `keccak256(abi.encodePacked(requestHash, timestamp, data))`, signed with EIP-191. Submit `data` bytes exactly as signed; do not re-serialize.
- **Tamper test tooling:**
  - `pnpm --silent fetch-response > response.json`
  - edit the file, then `pnpm submit-response --file response.json`
  - Wrong-key case: sign the digest with another key via `cast wallet sign`
  - Add all four cases as Forge tests.
- **Priced operations:** answer 402 until paid via x402 in **aUSD on Base Sepolia**. Set `PAYER_PRIVATE_KEY`; the payer needs no ETH. Faucet: https://api3dao.github.io/airnodehub-hackathon/faucet/
- **Shared quotas:** all teams share upstream limits. Cache responses and never poll in a loop.
- **Cherry-picking:** for moving values, keep the acceptance window narrow.
- **Semantics:** a signature proves the response came unaltered from that source. It does **not** prove the real-world claim is true.

**Recommended integrations with headroom (selection):**
- Nodary (crypto prices, no limit)
- Frankfurter / ECB (FX rates)
- GLEIF (legal entities, 60/min)
- Companies House (UK company register, 600/5 min)
- AeroDataBox (flight status, ~2,000 lookups for all teams for both days)
- CustomWeather / WeatherAPI (weather)
- NVD (CVEs)
- Polymarket, SportDB
- Full list: https://api3dao.github.io/airnodehub-hackathon/docs/integrations

---

## 4. Candidate project ideas (Friday morning; superseded by SupplierPulse)

1. **8D-report agent + quality-gate escrow** (Cardano only): a quality manager hires an agent on Sokosumi to draft an 8D report from a supplier complaint. Escrow releases only if the report passes an automated completeness check (D1–D8 filled, root-cause depth).
2. **Quality-gate escrow as a dev tool** (Cardano only): a verifier agent sits between buyer and any seller agent and releases payment only for work that passed a check.
3. **Supplier approval gate** (Cardano + API3): a buyer hires the agent on Cardano. The agent fetches signed GLEIF / Companies House data, and an EVM contract releases a first payment (aUSD) to the supplier only if the company is verified active.
4. **Parametric flight-delay cover** (Cardano + API3): a traveller pays the agent via x402. The agent submits signed AeroDataBox status, and the contract pays out if the delay exceeds X.
5. **Pay-per-call standards API** (Cardano x402, fallback).

Note for Cardano + API3: the two chains are coupled off-chain through the agent, not trustlessly. Be explicit about this in the pitch.

---

## 5. Team roles (proposed) and context per role

Use these as briefs when spawning subagents or when a human asks you to work on a role.

### Role A — cardano-payments
- **Goal:** Secure qualification ASAP. One paid x402 request on Cardano preprod with tx hash by **Fri ~13:00**, then upgrade to Masumi escrow.
- **Stack:** `@x402/cardano`, x402-express template, CF-hosted preprod facilitator, Blockfrost preprod key, Masumi quickstart, Sokosumi CLI 1.0.4.
- **Done when:** tx hash + explorer link + exact run commands are recorded in `docs/evidence.md`.

### Role B — agent-logic
- **Goal:** The agent that does the useful job (LLM and/or deterministic steps), plus the quality check that decides whether payment is released.
- **Constraints:** Small, inspectable inputs and outputs. Explain limits and missing information in the output. Edit `agent/instructions.md` in the Masumi template.
- **Done when:** one end-to-end Task completes in the Personal Workspace, then in the TUM Workspace.

### Role C — contracts (only if API3 is in scope)
- **Goal:** Solidity contract inheriting the starter's consumer pattern.
  - Stores Airnode address and request hash
  - Checks signer, request and freshness
  - Replay protection
  - Meaningful state change
- **Deploy target:** a testnet; Base Sepolia is suggested because aUSD payments live there. Confirm with the team.
- **Done when:** deployed address recorded, Forge tests for all four tamper cases pass.

### Role D — api3-integration (only if API3 is in scope)
- **Goal:** Fetch and cache signed responses, submit to the contract, provide a judge-runnable script for the tamper test.
- **Done when:** the documented script lets a judge run the valid case plus the 4 rejections.

### Role E — product-and-pitch
- **Goal:** Customer journey, README, Devfolio description, ≤ 2.5-minute demo video, timeline guard.
- **Done when:** README has setup + run commands; video recorded by **Sat 13:00**; submission done by **Sat 14:30**.

---

## 6. Timeline

| When | Milestone |
|---|---|
| Fri 10:30 / 11:00 | Cardano workshop / API3 workshop (Workshop Room). Attend. |
| Fri ~13:00 | First paid x402 tx on preprod saved. If API3: starter's ETH/USD flow working on a local chain. |
| Fri ~18:00 | Agent job works end to end. If API3: contract deployed on testnet with one valid response. |
| Fri night | Integrate the paths; add Masumi escrow |
| Sat 10:00 | Tamper test script done (if API3) |
| Sat 11:00 | **Feature freeze** |
| Sat 13:00 | Demo video recorded |
| Sat 14:30 | Submitted on Devfolio, repo public |
| Sat 15:00 | Hard deadline |

---

## 7. Security and repo hygiene — NON-NEGOTIABLE

- **Never** commit, print or paste:
  - private keys, seed phrases, API keys
  - `.env`, `.local/`
  - Sokosumi runtime keys, `ADMIN_KEY`, `BLOCKFROST_API_KEY_PREPROD`, `PRIVATE_KEY`, `PAYER_PRIVATE_KEY`
- `.gitignore` must contain at least: `.env`, `.env.*` (except `.env.example`), `.local/`, `node_modules/`, `out/`, `cache/`
- **Before any `git add`, run `git rev-parse --show-toplevel` and confirm it is this repo's root.** At least one team machine has a stray Git repo in the user's home directory. Committing from the wrong root would stage SSH keys and private files. Never run `git add .` outside the repo root.
- Testnets only (Cardano preprod, EVM testnet). Never use mainnet funds.
- Never ask a human for a private key or recovery phrase. Wallets sign; keys stay in the wallet or vault.
- Partner MCP servers can spend funds (`call-operation`). Confirm with a human before any paid call.

---

## 8. Working conventions for you (the coding agent)

- Ask before writing code if the idea or track scope is unclear.
- Prefer the official starters and pinned versions over code from memory. Cardano, Masumi and x402 APIs change fast, so read the linked docs instead of guessing. If unsure, say so.
- Keep a running `docs/evidence.md` with:
  - tx hashes and explorer links
  - Task IDs
  - contract addresses and network
  - exact run commands
- Keep the README current. It must let a judge set up and run the project.
- Small commits with clear messages. Do not rewrite shared history.
- When something fails, report the exact error and what you tried. Do not silently switch approach.

---

## 9. Support

- Hackathon Telegram: https://t.me/+mY6aLKS8OnlhZjJk
- Email: hackathon@tum-blockchain.com
- Cardano: 1:1 sessions with a Masumi engineer, mentors on site
- API3: Telegram, mentors on site