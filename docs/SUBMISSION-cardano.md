# Devfolio draft: Cardano track section

Draft for the Cardano part of our Devfolio description (track: "Agentic Commerce on Cardano"). Items marked TODO need the real SupplierPulse run.

---

## SupplierPulse agent on Cardano: paid per verified supplier check

**Customer.** Small manufacturers and procurement teams that pay suppliers in stages: an advance, then instalments, then the final payment. They check a supplier once, at onboarding. Months later the money still goes out, even if the supplier has since been dissolved or gone into liquidation.

**The job they pay for.** Before each payment stage, our agent checks the supplier's current Companies House status (signed through API3 AirnodeHub) and applies the decision in the SupplierPulse contract: the stage is **paid**, waits for the buyer's **approval**, or is **held** so that the remaining balance stays with the buyer. The buyer hires the agent per check through Masumi and pays in ADA on Cardano.

**Payment tied to the result.** The customer's ADA goes into Masumi escrow, not to us.

- **The agent delivers a verified decision** (paid, waiting or held). The result hash goes on chain on Cardano, and the escrow releases to the agent after the unlock time.
- **The agent cannot deliver one** (no signed registry data, the contract rejects the evidence, the deadline passes). No result goes on chain. The buyer requests a refund, our agent authorizes it automatically, and the full amount goes back from escrow to the buyer.

A held payment counts as a job well done. If we were paid only when the supplier passes, the agent would have a reason to approve. So the customer pays for a correct check, and gets the money back if no check happened.

### How it works

1. The buyer starts a job with the order ID and the supplier's company number (MIP-003 API, hired through Masumi).
2. The buyer's Masumi node locks the price (5 tADA) in the Masumi V2 escrow contract on Cardano preprod.
3. Our seller node sees the funds locked. The agent fetches the signed company profile from AirnodeHub, paying $0.01 per call via x402, and submits it to the SupplierPulse contract on Ethereum Sepolia. The contract checks the signer, the request, freshness and replay, then pays, waits or holds.
4. The agent returns the decision and the EVM tx hash as the job result. Masumi stores the result hash on Cardano, which is a permanent record of what the agent decided and when.
5. After the unlock time, the escrow pays the agent. If no decision was reached, the refund path runs instead (request → authorize → withdraw).

The two chains are linked by our agent, not trustlessly. Both legs can be checked on their explorers: the payment and result on Cardano, the decision on Ethereum. The agent is the trusted bridge between them.

### Cardano tools used

- **Masumi payment service** (self-hosted, preprod, V2 registration): escrow, result submission, refunds, automatic collection after the unlock time.
- **Masumi registry**: on-chain agent identity. Registration tx `90d88d3c…f281bdc`.
- **masumi Python SDK (MIP-003 agent API)**, with a compatibility layer we wrote for V2 registrations (`cardano-agent/masumi_v2.py`): SDK 1.2.0 cannot create V2 payments by itself.
- **Blockfrost** (chain access for the payment service), **Koios** (we verify each payout or refund on chain: how much left escrow into which wallet), **Cardanoscan** (explorer links).
- **Sokosumi**: TODO, listing pending. Today jobs are hired with our buyer script through a Masumi purchasing node.

### Proof on Cardano preprod (all in `docs/evidence.md`)

| What | Tx |
|---|---|
| Paid job, escrow lock | `d12f846f…4143fcd` |
| Result on chain | `0d7bc5e7…1051574` |
| **Seller paid**: 5 tADA from escrow into our selling wallet | `1929a3d1…5bf2a6a` |
| Check failed → **refund**: 5 tADA back to the buyer | `0fefbb1b…89ffe2b` |
| SupplierPulse, supplier dissolved → payment held → agent paid | lock `fc3e095e…417c06b`, result `00c676f1…b9de2eb`, payout `3ddd27bd…98af92b` |
| SupplierPulse, no data → refund | `3863ea54…59288cb` |
| TODO: SupplierPulse with real registry data and Sepolia tx | |

The SupplierPulse runs above used a simulated EVM side, while the contract deployment was pending; the Cardano legs are real. TODO: replace them with the real run.

### How it could run in real use

- **Business case.** Price per check (here 5 ADA, in production a fixed USDM price such as €1) against $0.01 of registry data plus gas. A procurement team with 40 suppliers and monthly instalments buys about 40 checks a month. The check runs only when a payment is due, not continuously.
- **Integration.** The buyer's procurement or AP tool hires the agent before each scheduled payment. The decision and its Cardano result hash form an audit trail: who was checked, on which evidence, with what outcome.
- **What changes for production.** Masumi mainnet with a stablecoin price, a second registry (GLEIF) for non-UK suppliers, and longer escrow deadlines matched to payment terms. Our demo uses ~46 min until the seller payout; the default is several hours.
- **Limits.** The agent is trusted to run the check and bridge the two chains. A registry status does not prove delivery, so delivery acceptance stays a separate buyer approval in the contract.

---

## Video: Cardano part (~60 s of the 2.5 min)

1. **Customer and problem** (10 s): a robot maker pays a motor supplier in three stages. The supplier was checked once, months ago.
2. **Hire the agent** (10 s): start a job with order ID and company number; 5 tADA locked in escrow (show the lock tx on Cardanoscan).
3. **The check** (15 s): the agent fetches signed registry data, the contract holds the payment because the supplier is dissolved (show the EVM tx).
4. **Paid for the decision** (15 s): result hash on Cardano, escrow pays the agent (show the payout tx). Then the no-data case: full refund to the buyer (show the refund tx).
5. **Business case** (10 s): 5 ADA per check against $0.01 of data. The buyer pays only for a check that actually happened.
