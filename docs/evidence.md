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

## SupplierPulse live run (Ethereum Sepolia, 2026-10-30)

Explorers: contract txs on [sepolia.etherscan.io](https://sepolia.etherscan.io), aUSD payments (x402, Base Sepolia) on [sepolia.basescan.org](https://sepolia.basescan.org).

| Item | Value |
|---|---|
| Contract | [`0x91d7dbae109029b2b1245179a68ac362799674d7`](https://sepolia.etherscan.io/address/0x91d7dbae109029b2b1245179a68ac362799674d7) (Ethereum Sepolia, chain 11155111) |
| Deploy tx | [`0x21731862868abbc5394aa72799db6e03881eb8cf59d300493e1d782f6e596871`](https://sepolia.etherscan.io/tx/0x21731862868abbc5394aa72799db6e03881eb8cf59d300493e1d782f6e596871) |
| Airnode (stored) | `0x392228E5CCA260313e5ed337Ed3561B59A1e4bFF` (Companies House) |
| Max age | 300 s |
| Buyer / agent wallet | `0xEb3EB6da882798062b30CeC11AAaDe306287ce41` (also paid the aUSD) |
| Supplier wallet | `0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC` |

### Orders

Both orders: 500000000000 + 1500000000000 wei, permit TTL 86400 s, milestone 0 approved by the buyer before the check.

| Order | Company | Create tx | Approve milestone 0 |
|---|---|---|---|
| 0 | `09729896` | [`0x3589f9da38ff2753bc399ee9ae7b2a1b4b1325c87201954deed11799cee6b97e`](https://sepolia.etherscan.io/tx/0x3589f9da38ff2753bc399ee9ae7b2a1b4b1325c87201954deed11799cee6b97e) | [`0x64639b0e7901fd16fe8aa673f70111604a09f143f17a0072b40009c5730d6cfc`](https://sepolia.etherscan.io/tx/0x64639b0e7901fd16fe8aa673f70111604a09f143f17a0072b40009c5730d6cfc) |
| 1 | `07418033` | [`0xad280cb11db7c51139e58c92f7740ea83d2ca401116f9e01fcfc4a54e8ac74b2`](https://sepolia.etherscan.io/tx/0xad280cb11db7c51139e58c92f7740ea83d2ca401116f9e01fcfc4a54e8ac74b2) | [`0xc1e2863978366a66d2633c56647059e436f9bc424529016d19b4ab3f69b55bdb`](https://sepolia.etherscan.io/tx/0xc1e2863978366a66d2633c56647059e436f9bc424529016d19b4ab3f69b55bdb) |

### Agent runs (`supplier-agent.sh`, fresh signed Companies House profile, $0.01 aUSD each)

| Order | Signed status | Outcome | x402 payment (Base Sepolia) | Contract tx (`checkAndRelease`) | Request hash | Signed timestamp |
|---|---|---|---|---|---|---|
| 0 | `active` | **Paid** (milestone 0, 500000000000 wei to the supplier) | [`0xc7a6651b910db763ef5be70ceca90c8195524e2e79ad7d43bd002227b89190d5`](https://sepolia.basescan.org/tx/0xc7a6651b910db763ef5be70ceca90c8195524e2e79ad7d43bd002227b89190d5) | [`0x40d395d728f5700756fd55117ef59fd501dca3a86cbb161f30d2a20b80d13f05`](https://sepolia.etherscan.io/tx/0x40d395d728f5700756fd55117ef59fd501dca3a86cbb161f30d2a20b80d13f05) | `0xcae416f2dce5fb6bb595eafe8c5f11ce9df4b33f8664042e10f8f776739fab48` | `1793368834` (15:00:34 CET) |
| 1 | `liquidation` | **Held** (2000000000000 wei stays refundable to the buyer) | [`0x64bc4a4bd54c5c94582ebcc93735729dee1ad0b274af1d2cbb9d7ffd37610bd5`](https://sepolia.basescan.org/tx/0x64bc4a4bd54c5c94582ebcc93735729dee1ad0b274af1d2cbb9d7ffd37610bd5) | [`0x5e6af4d67af9cb7174afb72e0ef80b176a7d87c173c85e8457d256383065009b`](https://sepolia.etherscan.io/tx/0x5e6af4d67af9cb7174afb72e0ef80b176a7d87c173c85e8457d256383065009b) | `0x31975e4f7156ae305cc9e62a96e86e78272cf4f44ab7743deb7ec018a0f32456` | `1793368852` (15:00:52 CET) |

State after the runs (`pulse-status.sh`): order 0 active, 500000000000 wei paid, next milestone 1 of 2, no permit (needs fresh evidence); order 1 held, 0 paid, 2000000000000 wei remaining.

### Tamper test (order 0)

Fresh signed response for `09729896` (`{"status":"active"}`, timestamp `1793368868`, x402 payment [`0x7eb81622de5b022ea1d4115b08d05d6154e79b4abf151d6399c7324d7043e024`](https://sepolia.basescan.org/tx/0x7eb81622de5b022ea1d4115b08d05d6154e79b4abf151d6399c7324d7043e024)), then tampered four ways. All four were rejected by the deployed contract in a dry run (`eth_call` against Sepolia), so no tx was sent and no gas was spent. The valid case is the order 0 run above.

| Case | Tamper | Result | Revert |
|---|---|---|---|
| (a) value edited | status changed to `dissolved` | rejected | `WrongSigner(0x08cF6d380EC65b34fF5EB35538DA47491753e9E3)` |
| (b) too old | signature timestamp moved back one hour (`1793365268`) | rejected | `StaleResponse(1793365268, 1793368860)` |
| (c) different request | request hash of company `00000001` (`0xf3ca035268fbff78c4ad82e305b60d6a1f5e7bb758d3170d821dfaa59cba28e4`) | rejected | `WrongRequest(bytes32,bytes32)` |
| (d) wrong signer | re-signed with random key `0x74D5A91F03A2892efCCfE9F13BC8d9DC75C04369` | rejected | `WrongSigner(0x74D5A91F03A2892efCCfE9F13BC8d9DC75C04369)` |

### Commands

```sh
cd api3
export PATH="$PATH:$HOME/.foundry/bin"; set -a; source .env; set +a   # EVM_RPC_URL, EVM_PRIVATE_KEY, PULSE_ADDRESS
forge script script/DeploySupplierPulse.s.sol --rpc-url "$EVM_RPC_URL" --broadcast --slow --gas-estimate-multiplier 800
cast call "$PULSE_ADDRESS" 'airnode()(address)' --rpc-url "$EVM_RPC_URL"
cast call "$PULSE_ADDRESS" 'companyRequestHash(string)(bytes32)' 07418033 --rpc-url "$EVM_RPC_URL"
id1=$(scripts/pulse-create-order.sh 09729896 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC 500000000000,1500000000000)
id2=$(ORDER_REF=PO-2 scripts/pulse-create-order.sh 07418033 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC 500000000000,1500000000000)
scripts/pulse-approve.sh "$id1" 0; scripts/pulse-approve.sh "$id2" 0
cast call 0xbeA34973e5f67F18F656A2C6070C64326C791808 'balanceOf(address)(uint256)' 0xEb3EB6da882798062b30CeC11AAaDe306287ce41 --rpc-url https://sepolia.base.org
ORDER_ID=0 scripts/supplier-agent.sh   # Paid
ORDER_ID=1 scripts/supplier-agent.sh   # Held
scripts/supplier-fetch.sh 09729896 r.json
for t in value stale request key; do ORDER_ID=0 scripts/pulse-submit.sh r.json $t; done   # each: REJECTED by contract
scripts/pulse-status.sh 0; scripts/pulse-status.sh 1
```

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

## SupplierPulse+ v2 integration and evidence status

The v2 contract, tests and local deployment scripts, data tools and fixtures, dashboard, and judge page are integrated in this branch. **V2 is not deployed on Sepolia.** There is no v2 deployment address, public testnet payment/hold/refund run, or testnet tamper transaction to report. The live v1 contract evidence above must not be presented as v2 evidence.

### Local Anvil verification (chain 31337; not public-network evidence)

A fresh local deployment of the current branch verified the end-to-end contract paths:

- Clean signed evidence was accepted; replay and the `value`, `stale`, `request`, and `key` tamper cases were rejected.
- Fresh clean evidence enabled the buyer-approved first milestone to release **500 demo tokens** to the supplier. The order view confirmed 500 tokens paid and 500 remaining.
- A separately held order was refunded to its buyer; the order view confirmed it was closed with zero remaining.
- The CLI displayed clean and failed-rule boolean labels correctly.

The local payout and refund were mined only on ephemeral Anvil and have no public explorer links. This run does not demonstrate Sepolia deployment, Sepolia transactions, live paid API3 requests, or the overnight agent. Current browser checks are summarized in [`demo/README.md`](../demo/README.md).

### Automated validation

| Suite | Result |
|---|---|
| Foundry contract tests | 100 passed |
| API3 request/data tests | 11 passed |
| API3 agent Python tests | 56 passed, 1 skipped (`cast` selector test; Foundry is unavailable); Windows shell/empty-return coverage passed |
| Cardano agent gate tests | 17 passed |

### Autonomous local Anvil agent run (30 October 2026)

The current-branch Python agent was run for four cycles from **18:27:22–18:28:59 UTC** against a fresh Anvil chain (chain `31337`, local contract `0xe6e340d132b5f46d1e472debcd681b2abc16e57e`) with `fetch-local.sh`, which signs from the committed illustrative local registry. It produced 15 local transactions: clean checks, two approved 500-token milestone payouts, two evidence-based holds, a supplier-wide stop, and four buyer refunds (including the no-data exit). The cycle report showed **$0.00** spend because no x402 or live registry calls were made. The final snapshots showed orders 0 and 2 active with 500 tokens paid each, and orders 1, 3, 4, and 5 closed with zero remaining.

Representative local transaction hashes:

| Action | Order | Local transaction |
|---|---:|---|
| Clean Companies House evidence | 0 | `0x5324afa3b914fd45f73f5762896bc608ac67b5103030720dd736c6b07f623057` |
| Held Companies House evidence | 1 | `0x95ceb41a0e4d535e82a358f75678127b35e3e79c6af61fa770248f3516bdd30c` |
| Milestone paid (500 demo tokens) | 0 | `0x8f671e15f06e9fa1891bbcd6d8f505bb489ac8582e25e6fe5137cbd7fec6c0b2` |
| Milestone paid (500 demo tokens) | 2 | `0x4db94efbcca77622b8af9a3c367e72ebbae7a9de02429159bab839224b0f16ec` |
| Supplier-wide stop | 4 | `0x61b5c836c64ad97426823bd476a6992ccac9362b54df024556be2d03b5784aea` |
| No-data exit refunded | 5 | `0x466a6c96490eefa45f84328b7fe1574de2079b97311d72637acc3734cc766349` |

These are ephemeral chain-31337 transactions, not Sepolia evidence. The accelerated local clock and local registry are test fixtures; they are not an overnight or live-agent run.

### Live API3 data fetches (Base Sepolia)

The five genuine signed fixtures below include the x402 payment transaction in their metadata. They support the live data-source verification described in [`data-sources.md`](data-sources.md), not an on-chain v2 contract run. The records are stale for contract submission; do not use them as fresh evidence.

| Source / supplier | Signed fixture | x402 payment transaction |
|---|---|---|
| Companies House `03778796` | [`ch-03778796-202610301614.json`](../api3/fixtures/ch-03778796-202610301614.json) | [`0xa6d5a8356f695766c844e310962c88fb677337036ff9d1d44327969aba997918`](https://sepolia.basescan.org/tx/0xa6d5a8356f695766c844e310962c88fb677337036ff9d1d44327969aba997918) |
| Companies House `07418033` | [`ch-07418033-202610301614.json`](../api3/fixtures/ch-07418033-202610301614.json) | [`0x4338a7e319f321e3e8218bbd3e4f240c9b51e6ab46f8b91736c4dc779451b1e2`](https://sepolia.basescan.org/tx/0x4338a7e319f321e3e8218bbd3e4f240c9b51e6ab46f8b91736c4dc779451b1e2) |
| Companies House `09729896` | [`ch-09729896-202610301614.json`](../api3/fixtures/ch-09729896-202610301614.json) | [`0xb1a74544cb2fc12fcd69015a47e1b04ef7a73dd494dc03a6fa5dc13b7b5befc4`](https://sepolia.basescan.org/tx/0xb1a74544cb2fc12fcd69015a47e1b04ef7a73dd494dc03a6fa5dc13b7b5befc4) |
| GLEIF `391200JI69LS8L648F30` | [`gleif-391200JI69LS8L648F30-202610301607.json`](../api3/fixtures/gleif-391200JI69LS8L648F30-202610301607.json) | [`0xa4f2ce0b540c045bad0f24e2e61dd00dc81e05303b9b13c8889a36c7b94f4a5c`](https://sepolia.basescan.org/tx/0xa4f2ce0b540c045bad0f24e2e61dd00dc81e05303b9b13c8889a36c7b94f4a5c) |
| GLEIF `52990092KBQJF8QBGJ50` | [`gleif-52990092KBQJF8QBGJ50-202610301607.json`](../api3/fixtures/gleif-52990092KBQJF8QBGJ50-202610301607.json) | [`0x4bed5393cb3eebde913aee4a44edd990e65a86963cffbf2c30e03bc0e36aa7c1`](https://sepolia.basescan.org/tx/0x4bed5393cb3eebde913aee4a44edd990e65a86963cffbf2c30e03bc0e36aa7c1) |

Five fixture calls represent $0.05 of the $0.08 total reported in `data-sources.md`; further paid requests are not needed for this integration step.
