# SupplierPulse+ research notes

**Status:** sourced working notes for the API3 hackathon submission

**Access date:** 30 October 2026
**Scope:** UK company insolvency context, the Carillion case, LEI registration status, and adjacent products. These sources establish context; they do not prove SupplierPulse+ can predict insolvency or prevent every loss.

## UK company insolvencies

The Insolvency Service reported **1,882 registered company insolvencies in England and Wales in September 2026**. Of these, 341 were compulsory liquidations and 1,420 were creditors' voluntary liquidations (CVLs). Together, liquidations were **1,761 / 1,882 = 93.6%** of that month's reported insolvencies. The remaining cases were 102 administrations and 19 company voluntary arrangements. This is a one-month composition, not a measure of the share of all UK suppliers that are distressed.

For the 12 months ending 30 September 2026, the reported rate was **49.9 insolvencies per 10,000 companies**, approximately one in 200. This is a rolling rate for England and Wales; the Insolvency Service notes that it is calculated against the effective register and is intended to smooth monthly volatility.

**Source:** [Company insolvencies, September 2026 — Insolvency Service](https://www.gov.uk/government/statistics/company-insolvencies-september-2026) (published 20 October 2026; accessed 30 October 2026). See also the [release collection](https://www.gov.uk/government/collections/company-insolvency-statistics-releases).

## Case study: Carillion

Carillion declared insolvency on **15 January 2018**, when the Official Receiver began liquidating its assets and contracts. The National Audit Office (NAO) describes Carillion as a major provider of public services: at liquidation it had around **420 UK public-sector contracts** and employed around **18,200 people in the UK**.

The NAO estimated the liquidation would cost UK taxpayers **£148 million** at the time of its 2018 report, while noting material uncertainty and that the final cost could take years to establish. The NAO also reported that Carillion had announced **£1.9 billion of new government work** after its first profit warning in July 2017; many contracts had already been agreed, and some were signed or varied later. These facts illustrate the potential consequences of continuing a major supplier relationship amid financial distress. The £148 million is an estimated cost to the UK taxpayer, **not** a quantified loss to Carillion's private-sector customers or suppliers.

This case supports the general motivation for monitoring supplier risk, but it does not demonstrate that a registry-status check would have predicted Carillion's failure. SupplierPulse+ checks registry facts and can enforce a buyer's payment condition; it is not a financial-health forecasting service.

**Sources:**
- [Investigation into the government's handling of the collapse of Carillion — NAO](https://www.nao.org.uk/reports/investigation-into-the-governments-handling-of-the-collapse-of-carillion/) (accessed 30 October 2026).
- [NAO press release: estimated cost of the liquidation and government work after the profit warning](https://www.nao.org.uk/press-releases/investigation-into-the-governments-handling-of-the-collapse-of-carillion/) (published 7 June 2018; accessed 30 October 2026).

## LEI registration status

GLEIF's public API supports filtering LEI records by `registration.status`. In the API's 30 October 2026 golden-copy snapshot, the filtered result metadata reported:

| Registration status | Records |
|---|---:|
| `LAPSED` | 1,215,130 |
| `ISSUED` | 1,996,911 |

Within those **two queried status groups**, lapsed records were **1,215,130 / (1,215,130 + 1,996,911) = 37.8%**. This denominator is deliberately limited to the `LAPSED` and `ISSUED` filter results; it should not be described as the percentage of every LEI record or as a supplier failure rate. A lapsed registration is not, by itself, proof that the legal entity is inactive or insolvent.

**Sources:** GLEIF API, `meta.goldenCopy.publishDate` = 30 October 2026, accessed 30 October 2026:
- [`LAPSED` LEI record count](https://api.gleif.org/api/v1/lei-records?filter%5Bregistration.status%5D=LAPSED&page%5Bsize%5D=1)
- [`ISSUED` LEI record count](https://api.gleif.org/api/v1/lei-records?filter%5Bregistration.status%5D=ISSUED&page%5Bsize%5D=1)

The counts are returned in the API response's `meta.pagination.total`; the one-record page size is used to retrieve the count without downloading the full dataset.

## Company-level timeline: JR LIQUIDATIONS LIMITED

[JR LIQUIDATIONS LIMITED (company 16355878)](https://find-and-update.company-information.service.gov.uk/company/16355878) is currently listed by Companies House with status **Liquidation**. Its filing history records an extraordinary resolution to wind up dated **29 September 2026**; the resolution was filed on **14 October 2026**, the same date the appointment of a voluntary liquidator was filed. The company was incorporated on **1 April 2025**.

This is a verified 2026 liquidation timeline, not evidence that SupplierPulse+ predicted the event or prevented a loss. It supports only a narrow counterfactual: if a buyer had required a fresh registry check before a later milestone, the status available at that check could have triggered the contract's hold rule. It says nothing about earlier payments, a specific buyer's exposure, or whether the prototype would have detected the change before the filing appeared.

**Sources:** [Companies House company profile](https://find-and-update.company-information.service.gov.uk/company/16355878) and [filing history](https://find-and-update.company-information.service.gov.uk/company/16355878/filing-history) (accessed 30 October 2026). The filing history identifies the resolution date separately from its filing date; do not describe 29 September as the date the document was filed.

For comparison, [A K Motor Services (Plymouth) Ltd, company 07418033](https://find-and-update.company-information.service.gov.uk/company/07418033) currently shows as in liquidation, but its voluntary liquidator appointment was filed on **31 March 2022**. It is outside the 2025/26 period. [LIQUIDATION CENTRE LIMITED, company 15312797](https://find-and-update.company-information.service.gov.uk/company/15312797) was dissolved on **14 July 2026**, which does not establish a qualifying liquidation start date.

## Prior art and claim boundaries

This is a narrow scan of public product and documentation pages, not an exhaustive market or patent search.

| Area | Existing work | Relation to SupplierPulse+ |
|---|---|---|
| Supplier financial-health monitoring | [RapidRatings](https://www.rapidratings.com/) describes financial-health ratings, risk analysis, and continuous monitoring for supplier and third-party risk. | Strong adjacent product category. SupplierPulse+ should not claim to invent supplier monitoring or financial-health scoring. Its prototype uses selected registry fields rather than a proprietary financial model. |
| Supply-chain risk monitoring | [Resilinc](https://resilinc.ai/products/agentic-ai-supply-chain-monitoring-sc-monitor/) describes supplier risk/compliance management, disruption monitoring, supplier networks, and impact analysis. | Adjacent monitoring and resilience tooling. Its public product description is not evidence that it performs this project's exact signed-record payment flow. |
| Smart-contract escrow building blocks | [OpenZeppelin Contracts documentation](https://docs.openzeppelin.com/contracts/5.x/api/utils#Escrow) documents reusable Solidity utilities and security patterns. | General-purpose on-chain components are prior art for contract construction; they do not, on their own, provide SupplierPulse+'s registry evidence policy or procurement workflow. |
| Signed API data consumed by contracts | [API3 AirnodeHub hackathon documentation](https://api3dao.github.io/airnodehub-hackathon/) describes signed API responses checked on-chain. Its [projection guide](https://api3dao.github.io/airnodehub-hackathon/docs/projections) explains that projections and request hashes bind the requested fields. | This is an explicit part of the project's starting ecosystem, not a novelty claim. |

**Positioning:** the project combines fresh signed registry evidence with buyer-approved, milestone-based payments, expiring permits, shared supplier trust tiers, and a budgeted agent. Describe that as this prototype's mechanism and integration—not as the first supplier-risk platform, first escrow, or first use of registry data on-chain. The project's own API3 challenge materials also list registry-conditioned payment as an idea.

## Research limitations and next checks

- The September 2026 insolvency figures are for **England and Wales** and are aggregate monthly data.
- The Carillion estimate is from the NAO's 2018 report and concerns government/taxpayer costs; it is not a measured loss for private counterparties.
- The LEI percentage is a dated ratio over the two statuses queried, not all legal entities, and not a credit or insolvency statistic.
- The JR LIQUIDATIONS LIMITED filing dates establish a 2026 liquidation timeline, not a financial-distress prediction or a measured avoided loss.
- Product pages describe vendors' own offerings. The comparison above is descriptive and does not establish feature-by-feature equivalence.
- Verify Companies House and GLEIF field paths against actual signed Airnode responses before making claims about the prototype's live data.
