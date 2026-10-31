# SupplierPulse: pitch script (2:30)

*Narration only: spoken while a general video of the website plays in the background. Nothing is shown live, and nothing in the words depends on what is on screen at a given moment. About 340 spoken words: 2:15 at a calm 150 words a minute, with room for pauses. Say it in your own words; keep the numbers and the facts exact.*

---

### 0:00–0:20 · The problem

> "Companies check a supplier once, at sign-up, then pay it in instalments for months. If that supplier goes into liquidation in between, the next payment is lost. Last year, one in 190 companies in England and Wales became insolvent. Your supplier was approved last month. That should not approve today's payment."

### 0:20–0:40 · What SupplierPulse does

> "With SupplierPulse, the buyer locks the order money in a smart contract. Before each instalment, our agent fetches a fresh record from the official company register: Companies House in the UK, or GLEIF for companies worldwide. A healthy supplier is paid when the milestone is due and the buyer approved delivery. A supplier in liquidation gets nothing more, and the rest goes back to the buyer."

### 0:40–1:05 · How it works, and why API3

> "The record comes from API3's AirnodeHub, signed by the Airnode. Our agent pays one cent for it over x402 and hands it to the contract. The contract checks it itself: the trusted signer, this exact supplier, less than five minutes old, never used before. Only then does it apply the buyer's rules. Without that signature, a forged 'active' could pay a company that is being wound up. Remove API3, and nothing can be paid."

### 1:05–1:50 · Tamper-proof, and live

> "We tested it against forgery. Change one value and keep the signature: rejected. A genuine record that is too old: rejected. A genuine record of another company: rejected. A record signed by a different key: rejected. Only a fresh, untouched record passes and issues the payment permit. Judges can run the same test themselves on our website.
> And it runs live, on Ethereum Sepolia, with real companies. Since Friday the agent has worked on its own: over twelve hundred cycles. Healthy suppliers were paid within seconds of their due dates, failed ones were held and refunded, and every step is public on chain."

### 1:50–2:15 · Limits, next steps, close

> "A signature proves what the register said, not that the goods arrive. That's why the buyer still approves each delivery. Next, we'd add the German Handelsregister and insolvency notices, which we couldn't find on AirnodeHub yet. SupplierPulse: one cent per check, so you never pay a supplier that has already failed."

---

**If the video runs short (1 minute):** keep "The problem" and the first two sentences of "Tamper-proof, and live", then go straight to the closing line.

**Don't say:**
- "credit score" or "predicts insolvency". It's registry evidence.
- "first" or "only solution". We don't claim that.
- that money moved on mainnet. Everything is testnet: Sepolia ETH and test aUSD.
