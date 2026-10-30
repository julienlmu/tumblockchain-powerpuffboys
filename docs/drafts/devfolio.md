# Devfolio submission text (DRAFT)

**DRAFT (Batu, 30 Oct).** Paste into Devfolio after the team review. `TODO` marks what does not exist yet. Before submitting, check every number against `docs/evidence.md`.

---

## Tagline

Payment permits that expire: every supplier payment needs fresh, signed proof that the supplier still exists.

## Problem

Companies vet a supplier once, at onboarding, and then pay advances and instalments for months. If the supplier goes into liquidation or is dissolved in the meantime, the next transfer still goes out, because nobody re-checks the register before each payment. Money paid to a company in liquidation is hard to get back.

Who has this problem: small manufacturers and procurement teams that pay several suppliers on a schedule, with no compliance team to re-check every payment.

## What we built

- **SupplierPulse contract** (Solidity, `api3/src/SupplierPulse.sol`).
  - The buyer locks an order and splits it into stages.
  - Each stage is paid only with a **permit** created from a fresh, signed Companies House record that says `active`.
  - A permit covers one order, one stage, one fixed supplier wallet and one amount, and it expires. Paying uses it up.
  - Any other status (`liquidation`, `dissolved`, …) holds the order, and the buyer takes the rest back.
- **The checking agent.**
  - Before each payment date it fetches the supplier's signed company profile from API3 AirnodeHub, paying per call with x402.
  - It submits the evidence to the contract and reports **paid**, **held** or **no data**, with the transaction as proof.
- **Pay-on-pass on Cardano** (`cardano-agent/`).
  - The buyer hires the agent through Masumi and pays tADA into escrow.
  - The agent gets the money only if the check really ran and was verified on chain. Otherwise it authorizes the buyer's refund automatically.
  - Blocking a payment to a failed supplier is a successful job too. The agent is paid for a correct decision, not for approvals, so it has no reason to approve.

## How it works

1. The buyer creates an order in the contract and locks the full amount. The supplier wallet and the supplier's company are fixed at this point.
2. The buyer hires our agent on Cardano. The fee goes into Masumi escrow on preprod.
3. Before a stage is due, the agent calls AirnodeHub's Companies House `getCompanyProfile`, projected to `status`. The response comes back signed by the Companies House Airnode.
4. The contract checks:
   - the signer is the expected Airnode;
   - the request is exactly this order's company;
   - the response is fresh;
   - the response was not used before.
5. `active` gives a permit for this stage. With the buyer's stage approval, the stage is paid. Any other status holds the order.
6. The agent posts the result on Cardano. The escrow releases its fee, or, if the check could not be completed, refunds the buyer.

## Cardano tools used

- **Masumi** on preprod: agent registration (V2), payment service, escrow with result submission and refund flow.
- Our own `masumi_v2.py` makes SDK 1.2.0 work with V2 registrations, with configurable job deadlines.
- **Koios** to verify the escrow payout or refund on chain (`receipt.py`).
- `TODO`: Sokosumi listing. Our agent is registered on Masumi but not yet in Sokosumi's agent list.

Proof (`docs/evidence.md`):
- a paid job that passed: result tx `4d622fc4d56338df6feb34c3e8a44f02105c280befb287f823f04f426d6e9a34`
- a job whose check failed and was refunded within 4.5 minutes: refund withdrawn tx `0fefbb1baef53e19c9a844c9261a374735bfcf5d59c84828b8f1538bd89ffe2b`
- `TODO`: a paid job running the SupplierPulse check itself.

## API3: who relies on the data, and what goes wrong if it is forged

- **Who relies on it:** the buyer's money. The signed `company_status` is the *only* input that decides whether a stage is paid to the supplier.
- **If it were forged:** an attacker (or a dishonest supplier, or a lazy agent) could turn `liquidation` into `active` and pull the next instalment out to a company that is being wound up.
  - With AirnodeHub, the edited response no longer matches the Airnode's signature, and the contract rejects it.
  - We tested this with a real signed response: `liquidation` edited to `active` reverts with `WrongSigner`.
- **Tamper test** (in the video):
  - a valid, fresh `active` response pays the stage;
  - an edited value, a stale response, another company's response, and a response signed by a different key are all rejected.
- **What we wanted but could not find on AirnodeHub:**
  - the German company register (Handelsregister / Unternehmensregister) and German insolvency notices (Insolvenzbekanntmachungen)
  - invoice or delivery confirmations from ERP systems

  So v1 covers UK suppliers only.

## How it could run in real use

- Procurement or accounts-payable tools call the agent before each scheduled supplier payment instead of trusting a one-time onboarding check.
- The fee per check is tiny next to the money it protects: about $0.01 per register lookup plus the agent fee.
- More registers (GLEIF for global entities, national registers as they become available on AirnodeHub) extend the coverage.
- Stablecoin settlement (e.g. USDM on Cardano) can replace test tokens.

## Honest limits

- The two chains are linked by our agent, not trustlessly. Each side is verifiable on its own explorer.
- A signature proves the register said it, not that the register is right.
- Registry status says nothing about delivery quality. The buyer still approves each stage.

## Links

- Repository: https://github.com/julienlmu/tumblockchain-powerpuffgirls
- Contract: `TODO` address and network
- Video: `TODO`
