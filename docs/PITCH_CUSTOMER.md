# Pitch: who uses SupplierPulse+ and why

One customer, three real numbers, one pitch line, and ready answers for the jury.

Every number below has its source and year. Numbers marked *illustrative* are made up for the story and must be said as an example, never as data.

## 1. The customer

**Kessler Antriebe GmbH** (fictional), a mid-size machinery maker near Augsburg, about 400 staff.

- It buys precision gearbox housings from a **UK supplier**, a limited company registered at Companies House.
- The order is €240,000 *(illustrative)*, paid in three milestones: 30% upfront so the supplier can buy material, 40% at the first delivery, 30% at the final delivery. Advance payments like this are normal for custom parts.
- Kessler's purchasing team checked the supplier once, at onboarding: register extract, bank details, a credit report. Then it pays invoices for months on the strength of that one check.

**What goes wrong.** Between the first and second payment the supplier goes into liquidation. Companies House shows it the same week. Nobody at Kessler looks, because the supplier was "already approved". The second milestone is paid. In a UK creditors' voluntary liquidation, an unsecured trade creditor usually gets back little or nothing (see the supporting facts below), so that money is gone.

**With SupplierPulse+.** Kessler locks the order amount in the contract. Before each milestone, the agent buys a fresh, signed Companies House record. The record says `liquidation`, not `active`, so the contract refuses to pay and holds the rest for Kessler, who refunds it. This is exactly our demo: order B uses a real UK company (07418033) whose Companies House status is liquidation.

### A German supplier: GLEIF

The same buyer also has German suppliers. There is no Companies House for Germany in our setup, so the contract checks **GLEIF**, the global Legal Entity Identifier register:

- Every company with an LEI (a 20-character ID, for example `391200…` or `529900…` for many German entities) has a public GLEIF record.
- The contract requires the entity status to be `ACTIVE` and the LEI registration to be `ISSUED`. If the company is dissolved or merged away, or stops renewing its LEI (`LAPSED`), the next payment is held.
- Our demo orders D and E use real German LEIs.

**Be honest about the limit.** Not every small German company has an LEI. It is required mainly for firms that trade financial instruments or deal with banks in certain ways, so GLEIF covers the larger and more established suppliers. A lapsed LEI is a warning sign, not proof of insolvency. A direct check of the German Handelsregister or the official insolvency notices (insolvenzbekanntmachungen.de) is the natural next data source. The contract design does not change: one more signed source, one more rule.

## 2. Real numbers

| # | Number | What it means | Source and year |
|---|---|---|---|
| 1 | **23,938** company insolvencies; rate **52.5 per 10,000** companies, about **1 in 190** | Companies that entered insolvency in England and Wales in one year | Insolvency Service, *Company Insolvency Statistics December 2025* (calendar year 2025): [gov.uk](https://www.gov.uk/government/statistics/company-insolvencies-december-2025/commentary-company-insolvency-statistics-december-2025) |
| 2 | **24,064** company insolvencies, **€47.9 billion** expected creditor claims | Insolvencies filed at German courts in one year, and what creditors were owed | Destatis press release No. 085, 13 March 2026 (calendar year 2025): [destatis.de](https://www.destatis.de/DE/Presse/Pressemitteilungen/2026/03/PD26_085_52411.html) |
| 3 | **726,735** companies dissolved; register of **5,427,787** companies | Companies removed from the UK register in one year | Companies House, *Companies register activities April 2024 to March 2025* (financial year 2024/25): [gov.uk](https://www.gov.uk/government/statistics/companies-register-activities-statistical-release-april-2024-to-march-2025/companies-register-activities-april-2024-to-march-2025) |

**How to use them:**
- Numbers 1 and 2 are the strong ones. They count real failures, and in Germany they come with a euro amount owed to creditors.
- Number 3 shows how fast the register changes, but most dissolutions are voluntary closures of dormant or small companies, not failures. Say "the register changes by hundreds of thousands of companies a year", never "726,735 companies failed".
- Note on number 1: the UK figure is for England and Wales. Scotland and Northern Ireland are counted separately.

**Supporting facts (secondary sources, use carefully):**
- UK creditors' voluntary liquidations, the most common UK insolvency process, often return nothing to unsecured creditors. An analysis of Insolvency Service data reports that in 86% of them no class of creditor recovered anything ([GGI Insider No. 136, March 2025](https://ggi.turtl.co/story/ggi-insider-no-136-march-2025/page/7)). This is one firm's analysis, not an official statistic.
- UK–Germany trade was £146.4 billion in the four quarters to the end of Q4 2024 ([UK government trade factsheet, May 2025](https://assets.publishing.service.gov.uk/media/681380d570b095d0d701185a/germany-trade-and-investment-factsheet-2025-05-02.pdf)). It shows the corridor is large.

**What we could not find:** a reliable number for how much money buyers lose specifically on advance payments to suppliers that later go insolvent, or on B2B advance-payment fraud. Don't quote one. If asked, say: "There is no clean public figure for that. What we can show is how many suppliers fail and how much their creditors are owed."

## 3. Pitch line (3 sentences)

> Last year 23,938 companies went insolvent in England and Wales, and German courts recorded 24,064 company insolvencies with €47.9 billion owed to creditors. A German manufacturer that pays a UK supplier in advance usually finds out weeks later, after the next milestone has already been paid. SupplierPulse+ checks the official register, Companies House or GLEIF, right before every payment, and the smart contract refuses to pay a supplier that is no longer in good standing.

Short version for a slide: **"1 in 190 UK companies became insolvent last year. We check before every payment, not once at onboarding."**

## 4. Ready answers for the jury

**"Who would use this?"**
> Purchasing and finance teams at mid-size manufacturers that pay suppliers in milestones or in advance, especially across borders, where they can't easily follow the local register. Think of a German machinery maker paying a UK parts supplier. Today they check the supplier once at onboarding. We make the check happen automatically before every payment, for one cent per check. Larger buyers could also use it to prove to auditors that every payment was checked against the register.

**"Does the wallet really belong to that company?"**
> The register check doesn't prove that, and it doesn't need to. The buyer gets the supplier's payout wallet the same way it gets an IBAN today: from a supplier it has already onboarded and checked (KYC), through its normal vendor master data process. The wallet is written into the order when the buyer creates it, and it can't be changed afterwards. Our job is the next question: is this already-known supplier still in good standing right before we pay it? If a bank account can be faked in an email, so can a wallet, and the same controls apply: confirm it through a known channel, never from an invoice.

**"What if the supplier is fine but doesn't deliver?"** (likely follow-up)
> Delivery stays the buyer's call. A milestone pays only when it is due, the register record is clean, and the buyer has approved it. We remove one risk, paying a company that has already failed. We don't replace the buyer's own checks.

**"Isn't a credit report enough?"** (likely follow-up)
> A credit report is a snapshot from onboarding or a monthly alert someone has to read. Our check runs right before the money moves, and the contract acts on it by itself. The record is signed by the data provider, so nobody can fake or replay an old "active" status.
