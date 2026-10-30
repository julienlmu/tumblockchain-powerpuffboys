# Evidence log

Running record of everything judges need to verify. Add an entry the moment something happens.
No secrets here: addresses, hashes and IDs only. Never keys, mnemonics or API keys.

Explorer (Cardano preprod): https://preprod.cardanoscan.io/transaction/<TX_HASH>

## Cardano: paid requests / jobs (qualification)

| When (CET) | Kind (x402 / Masumi) | Task ID or request | Amount + asset | Tx hash | Explorer link | Seller receipt verified? |
|---|---|---|---|---|---|---|
| 30 Oct 13:06 | Masumi escrow, pay-on-pass agent (app `mock`, outcome pass) | job `f2359d2a-ed4d-465b-ad8f-bc1bb40cda58`, purchase `ResultSubmitted` | 5 tADA | lock `cef9996cc16d5d3b018bef7eb5555e32e2103536cb85d3914f3b2179d49370a2`; result `4d622fc4d56338df6feb34c3e8a44f02105c280befb287f823f04f426d6e9a34` | [lock](https://preprod.cardanoscan.io/transaction/cef9996cc16d5d3b018bef7eb5555e32e2103536cb85d3914f3b2179d49370a2), [result](https://preprod.cardanoscan.io/transaction/4d622fc4d56338df6feb34c3e8a44f02105c280befb287f823f04f426d6e9a34) | Not yet: SDK default deadlines, escrow unlocks Sat 31 Oct 19:03 |

Proof files: `cardano-agent/proofs/job-*.json`.

## Masumi agent

| Item | Value |
|---|---|
| Name | `ppb pay-on-pass agent` (preprod) |
| Agent identifier | `67ab0c92c4ac1610895a1c965ee50aba41a8f1513b15240723b3bd0b10e01432821eb869e1711c8fdaec0090f133ae05941f68b4916cf4a0bb000000` |
| Registration tx | [`90d88d3cfcef5fa2e0276a0a710e399140009124f55e0429911e2f026f281bdc`](https://preprod.cardanoscan.io/transaction/90d88d3cfcef5fa2e0276a0a710e399140009124f55e0429911e2f026f281bdc), confirmed 30 Oct 13:01 |
| Price | 5 tADA per job, Disputable (Masumi escrow), V2 registration |
| Selling wallet | `addr_test1qr3l0k6npvhznqv8u0x7v6www8p4phnsjq8m8cxlmynpyxrdt6tjh8gq2f8m95av4jl0dpzxlugtg6v8aaafl2725kyqhuz79v` |
| Purchasing wallet (test buyer) | `addr_test1qrldwrtkgfrrn7z3cm964ug8sexheptkdazplz5vq8qej2ppzxctqj7xkry8989peauhfgxzg2qr8q67amm48l5vavysmuf5mv` |

## Sokosumi resources

| Resource | ID | Workspace | Notes |
|---|---|---|---|
| Vendor | `01a18c34-45b2-730f-8046-483be1279811` | — | `powerpuffboys`, created 30 Oct 10:46, role admin |
| Coworker | `01a18c35-f760-7551-a450-25495c0411f1` | Personal `01a18c19-c5b6-779e-9770-29c26fe3cef8` | `powerpuffboys-agent`, capability tasks, access GRANTED, 30 Oct 10:48 |
| TUM organization | `01a17942-e6dd-724f-bae6-458b6a0f715a` | slug `tum-hackathon-u4ve65` | Joined as member, 30 Oct 10:45 |

## API3 (only if in scope)

| Item | Value |
|---|---|
| Contract address | |
| Network | |
| Airnode address (stored) | |
| Request hash (stored) | |
| Deploy tx | |

### Tamper test

| Case | Expected | Result | Tx / revert reason |
|---|---|---|---|
| Valid, timely response | accept | | |
| (a) value edited | reject | | |
| (b) too old | reject | | |
| (c) different request | reject | | |
| (d) wrong signer | reject | | |

## Exact run commands

```sh
# Masumi services (payment + registry) on preprod, from masumi-services-dev-quickstart
docker compose up -d

# Cardano agent
cd cardano-agent
venv/bin/python -m unittest                      # 10 tests
venv/bin/python agent.py                          # seller, port 8080
cloudflared tunnel --no-autoupdate --url http://localhost:8080   # public URL for the registry / Sokosumi
venv/bin/python buy_job.py --input '{"task": "demo", "outcome": "pass"}'   # paid job, escrow releases
venv/bin/python buy_job.py --input '{"task": "demo", "outcome": "fail"}'   # not passed, buyer refunded
```
