# Evidence log

Running record of everything judges need to verify. Add an entry the moment something happens.
No secrets here: addresses, hashes and IDs only. Never keys, mnemonics or API keys.

Explorer (Cardano preprod): https://preprod.cardanoscan.io/transaction/<TX_HASH>

## Cardano: paid requests / jobs (qualification)

| When (CET) | Kind (x402 / Masumi) | Task ID or request | Amount + asset | Tx hash | Explorer link | Seller receipt verified? |
|---|---|---|---|---|---|---|
| 30 Oct 13:06 | Masumi escrow, pay-on-pass agent (app `mock`, outcome pass) | job `f2359d2a-ed4d-465b-ad8f-bc1bb40cda58`, purchase `ResultSubmitted` | 5 tADA | lock `cef9996cc16d5d3b018bef7eb5555e32e2103536cb85d3914f3b2179d49370a2`; result `4d622fc4d56338df6feb34c3e8a44f02105c280befb287f823f04f426d6e9a34` | [lock](https://preprod.cardanoscan.io/transaction/cef9996cc16d5d3b018bef7eb5555e32e2103536cb85d3914f3b2179d49370a2), [result](https://preprod.cardanoscan.io/transaction/4d622fc4d56338df6feb34c3e8a44f02105c280befb287f823f04f426d6e9a34) | Not yet: SDK default deadlines, escrow unlocks Sat 31 Oct 19:03 |
| 30 Oct 13:10 | Masumi escrow, pay-on-pass agent (app `mock`, outcome pass, short deadlines) | job `c00c4fcf-3967-44d4-aeb6-7dd1af2df057`, purchase `ResultSubmitted` | 5 tADA | lock `d12f846ff2089418fef72838b77093fe31f0fb50e26b141d392e7fbef4143fcd`; result `0d7bc5e70e33857a08d956ad2a9d14f5af1800dfa26eb86c0a0ac5b721051574`; seller payout `1929a3d1fc91e155a370e14b2bbfbea3e6ed05ab97fbdfaede8c62abd5bf2a6a` | [lock](https://preprod.cardanoscan.io/transaction/d12f846ff2089418fef72838b77093fe31f0fb50e26b141d392e7fbef4143fcd), [result](https://preprod.cardanoscan.io/transaction/0d7bc5e70e33857a08d956ad2a9d14f5af1800dfa26eb86c0a0ac5b721051574), [payout](https://preprod.cardanoscan.io/transaction/1929a3d1fc91e155a370e14b2bbfbea3e6ed05ab97fbdfaede8c62abd5bf2a6a) | **Yes.** Escrow `Withdrawn` 13:57: the payout tx moved 5 tADA from escrow into the selling wallet (net +4.338819 after the 0.661181 fee), checked on chain with `receipt.py`. The service collects 10 min after the unlock time |
| 30 Oct 13:13 | Masumi escrow, pay-on-pass agent (app `mock`, outcome fail): **refund path** | job `a81464d0-6740-4e75-9c23-f335fde02b46`, purchase `RefundWithdrawn` | 5 tADA | lock `457707eaf832319548525b12b6fb28f04958899d06aa631438e224ff35194820`; refund request `0dfec1b9d54b2f36b611860bc43dddb99ee87a8260b205d73ab09271c54f5eec`; refund authorized `a4f91f7f23b0c8f80a56f869dade19e852009c4a237a5e18c36adbbb2adfdde0`; refund withdrawn `0fefbb1baef53e19c9a844c9261a374735bfcf5d59c84828b8f1538bd89ffe2b` | [lock](https://preprod.cardanoscan.io/transaction/457707eaf832319548525b12b6fb28f04958899d06aa631438e224ff35194820), [refund request](https://preprod.cardanoscan.io/transaction/0dfec1b9d54b2f36b611860bc43dddb99ee87a8260b205d73ab09271c54f5eec), [refund authorized](https://preprod.cardanoscan.io/transaction/a4f91f7f23b0c8f80a56f869dade19e852009c4a237a5e18c36adbbb2adfdde0), [refund withdrawn](https://preprod.cardanoscan.io/transaction/0fefbb1baef53e19c9a844c9261a374735bfcf5d59c84828b8f1538bd89ffe2b) | n/a, refunded: the check failed, our refund guard authorized the buyer's request 44 s later, 5 tADA left escrow back to the buyer (net +4.345107 after the 0.654893 fee), 4.5 min after the job started |
| 30 Oct 13:52 | Masumi escrow, SupplierPulse app **(simulated EVM side)**, company `07654321` dissolved: payment **held** | job `09fa4cf7-0274-46cf-ac69-bcb603a6f856`, purchase `ResultSubmitted` | 5 tADA | lock `fc3e095eb7a1c9733b1cda53f2c925b091c28cf9a2882017bbf910d51417c06b`; result `00c676f11a3a8dbfe228cf8b9164899a69b6513db8614378679ad0de7b9de2eb`; seller payout `3ddd27bd1d9752bb6ff900b94e93679c4ba0aef486aea7ea5ee06dc5f98af92b` | [lock](https://preprod.cardanoscan.io/transaction/fc3e095eb7a1c9733b1cda53f2c925b091c28cf9a2882017bbf910d51417c06b), [result](https://preprod.cardanoscan.io/transaction/00c676f11a3a8dbfe228cf8b9164899a69b6513db8614378679ad0de7b9de2eb), [payout](https://preprod.cardanoscan.io/transaction/3ddd27bd1d9752bb6ff900b94e93679c4ba0aef486aea7ea5ee06dc5f98af92b) | **Yes.** A held payment is a delivered decision, so the agent is paid: escrow `Withdrawn` ~14:39, 5 tADA from escrow into the selling wallet (net +4.337939 after the 0.662061 fee), checked on chain with `receipt.py` |
| 30 Oct 13:55 | Masumi escrow, SupplierPulse app **(simulated EVM side)**, company `99999999`: **no data**, refund path | job `79293455-9de3-402b-9810-74ce42f38cc6`, purchase `RefundWithdrawn` | 5 tADA | lock `3aff726edbd25500e9e6931003d32a2cf98af33e34b5051127892ef2b2902f91`; refund request `ca0b8dc531f3f35af4cae5c944f39e0fb9b2b77f0f720094b8051253ff50804b`; refund authorized `f5a7c66a7d196d1e24e6be80dbf6997c022b1e8dc136a0fc78d713aa2cf53841`; refund withdrawn `3863ea54999d2fce3be815510aabce46e35cd109573f02bd46c0feb8859288cb` | [lock](https://preprod.cardanoscan.io/transaction/3aff726edbd25500e9e6931003d32a2cf98af33e34b5051127892ef2b2902f91), [refund request](https://preprod.cardanoscan.io/transaction/ca0b8dc531f3f35af4cae5c944f39e0fb9b2b77f0f720094b8051253ff50804b), [refund authorized](https://preprod.cardanoscan.io/transaction/f5a7c66a7d196d1e24e6be80dbf6997c022b1e8dc136a0fc78d713aa2cf53841), [refund withdrawn](https://preprod.cardanoscan.io/transaction/3863ea54999d2fce3be815510aabce46e35cd109573f02bd46c0feb8859288cb) | n/a, refunded: 3 attempts without a verified decision, no result on chain, 5 tADA back from escrow to the buyer (net +4.345107 after the fee) |

Proof files: `cardano-agent/proofs/job-*.json` (all txs of each job, both escrow sides, and the on-chain payout or refund amount via `receipt.py`).

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
venv/bin/python -m unittest                      # 16 tests
venv/bin/python agent.py                          # seller, port 8080
cloudflared tunnel --no-autoupdate --url http://localhost:8080   # public URL for the registry / Sokosumi
venv/bin/python buy_job.py --input '{"task": "demo", "outcome": "pass"}'   # paid job, escrow releases
venv/bin/python buy_job.py --input '{"task": "demo", "outcome": "fail"}'   # not passed, buyer refunded
venv/bin/python receipt.py --wait 3600 proofs/job-<id>.json                # after the unlock time: seller payout, checked on chain

# SupplierPulse with the simulated EVM side (until api3/scripts/supplier-agent.sh exists)
APP_CONFIG=apps/supplier-pulse-sim.json venv/bin/python agent.py
venv/bin/python buy_job.py --input '{"order_id": 0, "company_number": "07654321"}'   # held: agent paid
venv/bin/python buy_job.py --input '{"order_id": 0, "company_number": "99999999"}'   # no data: refunded
```
