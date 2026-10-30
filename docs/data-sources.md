# Data sources (SupplierPulse+)

Owner: Emre (§6.2 of `docs/SUPPLIERPULSE_PLUS.md`). Verified with live, paid AirnodeHub calls on Fri 30 Oct 2026, 17:07 CET.
Signed responses are in `api3/fixtures/` (they are stale by now, so on chain they give `StaleResponse`).

## Pointers: verified

All §4.2 pointers are correct. The Airnodes returned the request hashes that `api3/x402/requests.mjs` computes,
and the records were signed by the expected signers. **No interface change.**

| Source | Operation | Field | Pointer | Example values seen |
|---|---|---|---|---|
| Companies House | `getCompanyProfile` | `status` | `/company_status` | `active`, `liquidation` |
| | | `insolvency` | `/has_insolvency_history` | `true`, `false` |
| | | `accounts_overdue` | `/accounts/overdue` | `true`, `false` |
| | | `confirmation_overdue` | `/confirmation_statement/overdue` | `true`, `false` |
| GLEIF | `getLegalEntity` | `entity_status` | `/data/attributes/entity/status` | `ACTIVE` |
| | | `registration_status` | `/data/attributes/registration/status` | `ISSUED`, `LAPSED` |

Other possible values (from the registers' documentation, not all seen live): Companies House `company_status`
`dissolved`, `administration`, `receivership`, `voluntary-arrangement`, `insolvency-proceedings`, …;
GLEIF `entity_status` `INACTIVE`, `registration_status` `PENDING_TRANSFER`, `RETIRED`, `ANNULLED`, ….

## Missing fields

**Some Companies House profiles lack a projected field.** `12493325` answered HTTP 400
`The response has no value at "/accounts/overdue"` and signed nothing. As designed (§4.3), that is "no data":
the agent retries and the order can never be paid without evidence. Demo companies must have all four fields.

## Cost

- $0.01 per call, paid in aUSD on Base Sepolia over x402. The payer needs no ETH.
- **A 4xx answer is not charged.** 4 successful calls + 1 HTTP 400 cost 0.04 aUSD in total.
- Payment txs: `0x08cb49ad…6925`, `0xf5ca330d…a24f`, `0xa4f2ce0b…4a5c`, `0x4bed5393…a7c1` (full hashes in the fixtures, field `paymentTx`).

## Demo suppliers (§2.5)

| Order | Supplier | Register | Signed flags (30 Oct 17:07) | Fits |
|---|---|---|---|---|
| A (clean, CH, rules `0x07`) | **open**: `09729896` is **not** clean, see below | | | |
| B (liquidation) | `07418033` | [Companies House](https://find-and-update.company-information.service.gov.uk/company/07418033) | `liquidation`, insolvency, accounts and confirmation overdue | ✅ held with all four labels |
| C (accounts overdue, rules `0x02`) | `09729896` | [Companies House](https://find-and-update.company-information.service.gov.uk/company/09729896) | `active`, no insolvency, **accounts overdue**, confirmation overdue | ✅ held with "accounts overdue" although the status alone would pay |
| D (German LEI, active) | `391200JI69LS8L648F30` ASR Component GmbH (HRB 18162) | [GLEIF](https://search.gleif.org/#/record/391200JI69LS8L648F30) | `ACTIVE` / `ISSUED` | ✅ clean |
| E (LEI lapsed) | `52990092KBQJF8QBGJ50` MoKa Projekt GmbH (HRB 748644) | [GLEIF](https://search.gleif.org/#/record/52990092KBQJF8QBGJ50) | `ACTIVE` / `LAPSED` | ✅ held with "LEI registration not issued" |

**`09729896` was planned as the clean supplier for order A, but its signed record has accounts and confirmation
statement overdue.** With rules `0x07` order A would be held at the first check. It fits order C instead.
Order A still needs an active UK company with all four fields present and nothing overdue.

Other German LEIs found with the free GLEIF search (`api.gleif.org`, `filter[entity.legalAddress.country]=DE`), not fetched paid:
- `ACTIVE`/`ISSUED`: `3912002Y0JWR1UBSYC82`, `391200EKSML2GJG11T92`, `98450063CFH811SD4084`
- `ACTIVE`/`LAPSED`: `529900JEZ1ZT4GN3A805`, `529900FBMWKX4E67W728`, `529900XKK4OSTEDEN668`, `529900DFZKP6OE5TEN96`
