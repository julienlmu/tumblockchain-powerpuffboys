# Brainstorming: mining payouts, price feeds, and agent payments

**Status:** exploration only; this is not a team decision or a replacement for the current project plan.

## The idea we explored

Build a mining payout service that tracks the mining work/rewards attributable to a user, values each confirmed reward at the coin's price when the reward is earned, and adds that fiat-denominated value to the user's in-app “savings box.” When the user ends a session or withdraws, the service pays the accumulated balance, potentially through Cardano.

Example: a user's share of a pool reward is 1 DOGE. If that reward becomes attributable to the user when DOGE is worth $0.20, the service records a $0.20 credit. The balance is not subsequently repriced just because DOGE moves before withdrawal.

The proposed differentiator is **clear, timestamped valuation of mining rewards and predictable settlement**, not increasing the amount of cryptocurrency the user's hardware mines.

## Possible flow

1. A miner connects to a supported pool/account, or the demo uses clearly labeled simulated pool data.
2. The service reads confirmed shares/rewards and calculates the user's attributable reward under the pool's payout rules.
3. At the defined reward-credit event, the service records the coin amount, price source, price timestamp, fees, and fiat-equivalent credit.
4. A settlement agent monitors accrued rewards and may sell confirmed coins on a configured cadence or after a minimum amount is reached.
5. The user sees a transparent ledger and withdraws an available balance. A Cardano transaction could provide payment or settlement evidence, depending on the chosen payout asset and implementation.

## Where API3 could fit

API3 can provide an oracle path for external API data, such as a crypto/USD price. That price can be used as the valuation input recorded with a reward. API3 does not mine coins, calculate pool rewards, execute exchange trades, or guarantee the exchange's fill price.

The product must distinguish:

- **Reference valuation:** the price used to calculate the user's credit.
- **Actual liquidation:** the amount received when the company sells the mining reward on an exchange, including spread, fees, timing, and slippage.

If the service credits a fixed fiat amount before it has sold the corresponding reward, the company temporarily carries price and settlement risk. Selling confirmed rewards periodically can reduce coin exposure, but cannot eliminate execution delay, exchange, liquidity, custody, or accounting risks. The actual sale price should come from the exchange execution, not be represented as the oracle's reference price.

Before selecting API3, confirm the supported data source, update/response behavior, costs, and whether the oracle output can be consumed by the intended payment/contract chain. A price feed that only updates periodically is not necessarily a second-by-second price guarantee.

## Where Cardano could fit

Cardano could be used for a paid service/agent flow or to record/settle a payout. The team must decide what asset is paid, where it is held, how an off-chain mining reward is reconciled with an on-chain payment, and whether any conversion or bridge is required. Do not imply that Cardano itself performs mining or that an oracle feed automatically transfers funds.

## Important product and technical questions

- Which proof-of-work coin and mining pool are supported first?
- What event makes a reward “earned”: submitted shares, pool-account accrual, or confirmed pool payout?
- How are pool-specific PPS/PPLNS/FPPS rules, fees, payout thresholds, rejected shares, and reward delays handled?
- Does the user receive mined coin, a fiat-denominated claim, a stablecoin, or another crypto amount?
- If fiat value is locked at earning time, what backs that claim until liquidation/withdrawal, and who bears any shortfall?
- How are exchange credentials secured and what trade limits, minimums, and withdrawal controls apply?
- What exact role does API3 play on the chosen chain, and what is the fallback if a price response is late or unavailable?
- What Cardano transaction demonstrates the paid service or payout, and how does it correspond to the off-chain ledger?
- Which jurisdiction and custody/compliance requirements apply before treating this as a real-money product?

## Scope and pitch for a hackathon prototype

The full service is broad. A focused prototype could use one coin, one pool data format (or simulated data labeled as such), one valuation feed, and a test payment. Show the reward amount, valuation timestamp/source, fees, accrued balance, and settlement calculation in an auditable ledger. Do not claim to outperform pools or guarantee profitability. Treat exchange execution and real custody as out of scope unless they can be implemented safely and demonstrated end to end.

## Other concepts discussed

- A betting/prediction site around AI agent balances: judged as a weaker fit because the role of the AI agent and the reason to use Cardano/API3 were unclear.
- A marketplace of task-specific company agents with usage-based billing: a plausible Cardano paid-agent concept, but API3 needed a genuine external-data/API role rather than an artificial integration.
- An automated agent that monitors confirmed mining rewards, references a price feed, and settles them: the most coherent API3 angle explored so far, but still exploratory and subject to the questions above.

## Current conclusion

The mining settlement concept is not inherently incoherent. Its value proposition is transparent reward valuation at a defined time and a predictable settlement experience. API3 may supply reference price data; an agent may automate monitoring and settlement; Cardano may support the paid workflow or payment record. None of those components by itself increases mining yield, and the team has not yet selected this concept as the project.
