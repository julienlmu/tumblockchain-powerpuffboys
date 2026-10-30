# Data sources (SupplierPulse+)

Owner: Emre (§6.2 of `docs/SUPPLIERPULSE_PLUS.md`). Verified with live, paid AirnodeHub calls on Fri 30 Oct 2026:
the spec v1.0 pointers at 17:07 CET, the **v1.1 pointers at 17:14 CET**.
Signed responses are in `api3/fixtures/` (they are stale by now, so on chain they give `StaleResponse`).

## Pointers (spec v1.1): verified

All §4.2 v1.1 pointers are correct. The Airnodes returned the request hashes that `api3/x402/requests.mjs` computes,
and the records were signed by the expected signers. **No interface change.**

| Source | Operation | Field | Pointer | Values seen live |
|---|---|---|---|---|
| Companies House | `getCompanyProfile` | `status` | `/company_status` | `active`, `liquidation` |
| | | `accounts_overdue` | `/accounts/next_accounts/overdue` | `true`, `false` |
| | | `confirmation_overdue` | `/confirmation_statement/overdue` | `true`, `false` |
| GLEIF | `getLegalEntity` | `entity_status` | `/data/attributes/entity/status` | `ACTIVE` |
| | | `registration_status` | `/data/attributes/registration/status` | `ISSUED`, `LAPSED` |

The v1.0 pointers `/accounts/overdue` and `/has_insolvency_history` also worked live, but v1.1 dropped them (deprecated in the Companies House schema).

Other possible values (from the registers' documentation, not all seen live): Companies House `company_status`
`dissolved`, `administration`, `receivership`, `voluntary-arrangement`, `insolvency-proceedings`, …;
GLEIF `entity_status` `INACTIVE`, `registration_status` `PENDING_TRANSFER`, `RETIRED`, `ANNULLED`, ….

## Missing fields

**Some Companies House profiles lack a projected field.** `12493325` answered HTTP 400 with v1.0
(`no value at "/accounts/overdue"`) and with v1.1 (`no value at "/accounts/next_accounts/overdue"`), and signed nothing.
As designed (§4.3), that is "data unavailable": no payment without evidence, and the no-data exit applies.
All five demo suppliers have every field (fallback 1 of §4.2), so no template change is needed.

## Cost

- $0.01 per call, paid in aUSD on Base Sepolia over x402. The payer needs no ETH.
- **A 4xx answer is not charged.** The two HTTP 400s for `12493325` cost nothing.
- Spent so far: $0.08 (8 successful calls) of the $0.60 budget. Payment txs are in each fixture's `paymentTx`.

## Demo suppliers (§2.5)

| Order | Supplier | Register | Signed flags (v1.1, 30 Oct 17:14) | Fits |
|---|---|---|---|---|
| A (clean, CH, rules `0x06`) | `03778796` ELECTRIC MOTORS INTERNATIONAL LIMITED | [Companies House](https://find-and-update.company-information.service.gov.uk/company/03778796) | `active`, nothing overdue | ✅ clean |
| B (liquidation) | `07418033` | [Companies House](https://find-and-update.company-information.service.gov.uk/company/07418033) | `liquidation`, accounts and confirmation overdue | ✅ held: registry status not active, accounts overdue, confirmation statement overdue |
| C (accounts overdue, rules `0x02`) | `09729896` POOLE BRIDGE MOTOR COMPANY LTD | [Companies House](https://find-and-update.company-information.service.gov.uk/company/09729896) | `active`, **accounts overdue**, confirmation overdue | ✅ held with "accounts overdue" although the status alone would pay |
| D (German LEI, active) | `391200JI69LS8L648F30` ASR Component GmbH (HRB 18162) | [GLEIF](https://search.gleif.org/#/record/391200JI69LS8L648F30) | `ACTIVE` / `ISSUED` | ✅ clean |
| E (LEI lapsed) | `52990092KBQJF8QBGJ50` MoKa Projekt GmbH (HRB 748644) | [GLEIF](https://search.gleif.org/#/record/52990092KBQJF8QBGJ50) | `ACTIVE` / `LAPSED` | ✅ held with "LEI renewal overdue" |

For C3: `DEMO_CH_A=03778796 DEMO_CH_B=07418033 DEMO_CH_C=09729896 DEMO_LEI_D=391200JI69LS8L648F30 DEMO_LEI_E=52990092KBQJF8QBGJ50`

**`09729896` was planned as the clean supplier for order A, but its signed record has accounts and confirmation
statement overdue**, so order A would be held at the first check. It fits order C instead. Order A uses `03778796`,
pre-screened for free on the Companies House website (status, "overdue" labels, insolvency tab), then confirmed with paid calls.

Other German LEIs found with the free GLEIF search (`api.gleif.org`, `filter[entity.legalAddress.country]=DE`), not fetched paid:
- `ACTIVE`/`ISSUED`: `3912002Y0JWR1UBSYC82`, `391200EKSML2GJG11T92`, `98450063CFH811SD4084`
- `ACTIVE`/`LAPSED`: `529900JEZ1ZT4GN3A805`, `529900FBMWKX4E67W728`, `529900XKK4OSTEDEN668`, `529900DFZKP6OE5TEN96`

## Genuine tamper inputs (§4.7 v1.1)

Untouched, genuinely signed records for the video and for judges:

| Case | File | Submit to | Expected |
|---|---|---|---|
| (b) too old | `api3/fixtures/ch-09729896-202610301614.json` (real record, older than `maxAge` since 17:19) | order C (`09729896`) | `StaleResponse` |
| (c) different request | a **fresh** `fetch-evidence.sh ch 07418033` record | order A (`03778796`) | `WrongRequest` |

The spec suggested `12493325` for (c), but it returns no data (see above). Any other real company works the same way; `07418033` is already in the demo.
