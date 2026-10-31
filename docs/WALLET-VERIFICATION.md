# Q&A: How would you verify that the payout wallet belongs to the supplier?

## Ready-to-say answer

> Today, the buyer verifies the supplier and payout details during its normal onboarding, just as it verifies a bank account. A future version could add a cryptographic wallet-binding step: the supplier proves control of the wallet, and an authorized company representative confirms that the wallet is the company's approved payout address. The buyer approves that binding before creating the order. The contract would enforce the approved address, but we would be clear that a cryptographic signature proves control of a wallet—not, by itself, legal ownership by the company.

## How we would implement it

1. **Verify the company representative.** During supplier onboarding, the buyer uses its existing KYB/KYC process or an identity provider to verify that the person is authorized to act for the company. That real-world authorization cannot be established by a wallet signature alone.
2. **Prove control of the payout wallet.** Ask the supplier to sign a one-time, expiring message containing the registry and company ID, wallet address, network/chain ID, and a fresh nonce. This proves control of that wallet and prevents the signature from being replayed for another company, chain, or order.
3. **Record the buyer's approval.** After checking the representative through onboarding, the buyer approves the company-to-wallet binding. Store the binding on-chain, or store a signed attestation and its hash. Do not put personal KYC documents on-chain.
4. **Enforce the binding at order creation.** The contract checks that the order's supplier ID and payout address match the approved binding. The payout address remains fixed for the order.
5. **Handle changes visibly.** Changing a payout wallet requires a new control proof and buyer approval. Notify both parties, keep the old binding and its history auditable, and apply the new address only to orders that explicitly accept it.

## What this proves—and does not prove

- The wallet signature proves that someone controlling the wallet signed the message.
- The buyer's onboarding process establishes why it believes that signer is authorized to bind the company.
- The contract can enforce the approved payout address and make changes auditable.
- The contract cannot independently prove legal ownership or corporate authority from the wallet signature alone.

A company-controlled multisig can provide stronger operational control, but should be an option rather than a requirement for every supplier.

**Product status:** This is a proposed feature, not a capability of the current contract. Today the buyer supplies and verifies the payout address during supplier onboarding and the contract fixes that address for the order.
