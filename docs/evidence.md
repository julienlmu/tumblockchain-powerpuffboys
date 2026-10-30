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

## SupplierPulse+ live (Ethereum Sepolia)

| Item | Value |
|---|---|
| Contract | [`0xf25Aae1772326C95294D1923399D55c658493DfC`](https://sepolia.etherscan.io/address/0xf25Aae1772326C95294D1923399D55c658493DfC) (Ethereum Sepolia, chain 11155111) |
| Deploy tx | [`0x2db57f1f6e10acfe03f8eb31712b168e1e4278d20b182e7160cfe07b83684e99`](https://sepolia.etherscan.io/tx/0x2db57f1f6e10acfe03f8eb31712b168e1e4278d20b182e7160cfe07b83684e99) |
| Block | 12028086 |
| Deployer / admin | `0xEb3EB6da882798062b30CeC11AAaDe306287ce41` |
| Source commit | `c668c51869e9f6a80c0dbc841967c171572dd717` (`supplierpulse-plus`, includes the C2.5 fixes; `forge test` 115/115) |
| CH airnode (`airnodeOf(0)`) | `0x392228E5CCA260313e5ed337Ed3561B59A1e4bFF` (Companies House) |
| GLEIF airnode (`airnodeOf(1)`) | `0x26d83124541e89ef28B9A5FB012B4B5f4097C20c` |
| maxAge / tierCountGap / refundGrace | 300 s / 300 s / 600 s |
| Gas | 25,498,993 gas × 10,017 wei = 0.000000255423412881 ETH |

Verified on chain after the deploy (`cast call`): `maxAge()` = 300, `tierCountGap()` = 300, `refundGrace()` = 600, `airnodeOf(0)` = `0x392228E5CCA260313e5ed337Ed3561B59A1e4bFF`, `airnodeOf(1)` = `0x26d83124541e89ef28B9A5FB012B4B5f4097C20c`, `admin()` = `0xEb3EB6da882798062b30CeC11AAaDe306287ce41`, `ordersLength()` = 0; receipt status 1 (success). All as expected.

Deploy command (from `api3/`, `EVM_PRIVATE_KEY` in the environment):

```
MAX_AGE=300 TIER_COUNT_GAP=300 REFUND_GRACE=600 forge script script/DeploySupplierPulsePlus.s.sol --rpc-url https://ethereum-sepolia-rpc.publicnode.com --broadcast --slow --gas-estimate-multiplier 800
```

### Demo orders A–E (created 30 Oct, 19:43–19:48 CET)

Buyer `0xEb3EB6da882798062b30CeC11AAaDe306287ce41`. Supplier 1 = `0x535d7e4d7f6c3B13F34da2aC98afE379912bed4a`, supplier 2 = `0x8cACCFf7C1a3384800cD9ff394448DB41b655c28`. Amounts in tokens (1 token = 10^12 wei). Permit TTL 1800 s for all. Values read back with `orderInfo` / `orderMilestones` / `orderSchedule`.

| Label | Order id | Supplier id | Source | Rules | Supplier wallet | Amounts | Due dates (unix → CET) | Approved | createOrder tx |
|---|---|---|---|---|---|---|---|---|---|
| A · PO-1001 Motor supply | 0 | `03778796` | Companies House (0) | `0x06` | supplier 1 | 500 / 1,000 / 1,500 | 1793387004 (30 Oct 20:03:24) / 1793443500 (31 Oct 11:45) / 1793457000 (31 Oct 15:30) | 0, 1 | [`0xb6c320…5bc4`](https://sepolia.etherscan.io/tx/0xb6c320f591a20435d27217945cf6012daf024c41ce974c7ceaa12b84ffeb5bc4) |
| B · PO-1002 Gearbox | 1 | `07418033` | Companies House (0) | `0x06` | supplier 2 | 1,000 / 2,000 | 1793387052 (30 Oct 20:04:12) / 1793443500 (31 Oct 11:45) | 0 | [`0xfd2fb4…2d25`](https://sepolia.etherscan.io/tx/0xfd2fb477d10e669a8c139636fe1f1ff06fdbab10927cf9f8ec792a0489bb2d25) |
| C · PO-1003 Sensors | 2 | `09729896` | Companies House (0) | `0x02` | supplier 1 | 500 / 500 | 1793387076 (30 Oct 20:04:36) / 1793444400 (31 Oct 12:00) | 0 | [`0x16b512…e85f`](https://sepolia.etherscan.io/tx/0x16b512db25a552f859eb486e2962862e15a1d199c3476f81376999c135d1e85f) |
| D · PO-1004 Cable harness (DE) | 3 | `391200JI69LS8L648F30` | GLEIF (1) | `0x08` | supplier 1 | 500 / 1,000 | 1793387772 (30 Oct 20:16:12) / 1793444400 (31 Oct 12:00) | 0, 1 | [`0x26197a…b7db`](https://sepolia.etherscan.io/tx/0x26197ae08cf3df9e13d34f257e0b8e748b9411586c1ea8e238c93f91653eb7db) |
| E · PO-1005 Castings | 4 | `52990092KBQJF8QBGJ50` | GLEIF (1) | `0x08` | supplier 2 | 500 / 500 | 1793387808 (30 Oct 20:16:48) / 1793444400 (31 Oct 12:00) | 0 | [`0x07adaa…0a55`](https://sepolia.etherscan.io/tx/0x07adaa7bdaa92c9e76a074c21088684c1f00a13c9aa31671b561972565a70a55) |

Approval txs (`approveMilestone`): A m0 `0xc4c0515cedef370538fb8081a5a36f49537347fbea60778e2f29afc06f241d76`, A m1 `0x693316481fb3f3338faeb677504d498fb03ae2a4c11774f8572543a54ad6fe95`, B m0 `0x02bb5d51ef6dc56aec47286a21593af329e273ee8707c3f3ebf63e8157e4a1bb`, C m0 `0x0768c6ea71a0b732c230056cdb5bae583be658f26e51eac4069fe44ff8952e9b`, D m0 `0x030812c65ae531c29ed87a58696876e762158cd9ddb5f7b3d1df987427644659`, D m1 `0x76d4b0f35228c457061d8af7fbac9fb9d880eab911fa10ab3b1948124c0a9e32`, E m0 `0xcde10b30185f4425a4737ace8e3cfce6d48f39fe20d8e41f657ace9c206718b1`. `ordersLength()` = 5 afterwards.

The agent wallet `0xED34…253a` acted within a minute of creation: B held with failedRules `0x86` ([`0x254f08…2323`](https://sepolia.etherscan.io/tx/0x254f08265550daf0c8de4d20fb29a3dd7310c9050e59339bb87f6d40b1742323)), C held with `0x02` ([`0xbcc39c…d441`](https://sepolia.etherscan.io/tx/0xbcc39c8fc274c8674bac7b410b1cbc321cc1e82dc49640c7eabacbe8ed6dd441)).

Buyer balance 0.049347717179651758 → 0.039757540142535541 ETH: 0.0095 ETH locked in the orders, 0.000090177 ETH gas.

Run command (from `api3/scripts`, `BUYER_PRIVATE_KEY` in the environment from the local, uncommitted `api3/.env`):

```
EVM_RPC_URL=https://ethereum-sepolia-rpc.publicnode.com PULSE_PLUS_ADDRESS=0xf25Aae1772326C95294D1923399D55c658493DfC \
DEMO_SUPPLIER_1=0x535d7e4d7f6c3B13F34da2aC98afE379912bed4a DEMO_SUPPLIER_2=0x8cACCFf7C1a3384800cD9ff394448DB41b655c28 \
./plus-demo-orders.sh
```

The script stopped after creating C because one RPC call failed (no tx sent). C's approval, D and E were then sent one by one with `plus-approve.sh` and `plus-create-order.sh`, with the same arguments the script uses, after checking `ordersLength()` before each step. No order is duplicated.

### Judge CLI against live v2 (Emre, 30 Oct 20:10 CET)

Fresh real signed records, fetched with `api3/scripts/fetch-evidence.sh` ($0.01 aUSD each on Base Sepolia), then checked with `api3/scripts/plus-submit.sh` (an `eth_call` simulation of `submitEvidence`, so nothing is sent).
Order states at 20:10: A (0) and D (3) active; B (1), C (2) and E (4) already held by the agent and refunded (closed).

| Case | Record | Order | Contract verdict |
|---|---|---|---|
| Valid, timely | fresh `03778796` (`api3/fixtures/ch-03778796-202610301910.json`) | A (0) | `ACCEPTED clean` |
| Valid, timely | fresh `391200JI69LS8L648F30` (`api3/fixtures/gleif-391200JI69LS8L648F30-202610301910.json`) | D (3) | `ACCEPTED clean` |
| (a) value edited | the fresh A record, status `active` → `liquidation`, signature unchanged | A (0) | `REJECTED WrongSigner(0x6D3B…DeD3E)` |
| (b) too old, mutated | the fresh A record, timestamp −1 h | A (0) | `REJECTED StaleResponse` |
| (b) too old, **genuine** | untouched real A record from 17:14 (`api3/fixtures/ch-03778796-202610301614.json`) | A (0) | `REJECTED StaleResponse(1793376875, 1793387424)` |
| (c) other request, mutated | the A record's request hash replaced by the one for `00000001` | A (0) | `REJECTED WrongRequest` |
| (c) other request, **genuine** | untouched fresh real `07418033` record (`api3/fixtures/ch-07418033-202610301910.json`) | A (0) | `REJECTED WrongRequest(0xb3d4…67d6, 0xa6d1…f452)` |
| (d) wrong key | the fresh A record re-signed by a random key | A (0) | `REJECTED WrongSigner(0xd494…6a9c)` |
| Closed order | fresh `07418033` record | B (1) | `REJECTED NotActive(2)` |

x402 payments for the three records (Base Sepolia): [`0x5eba18de…6749`](https://sepolia.basescan.org/tx/0x5eba18de17698c10a6504206eb47b15182465a1609831f6d8dd3637fb0576749), [`0x5a8d3b5d…7841`](https://sepolia.basescan.org/tx/0x5a8d3b5d3654f0611a975f25ca87cf4bb3bae4d26396f1c6269540a839437841), [`0x19f2e0d3…7b44`](https://sepolia.basescan.org/tx/0x19f2e0d3f9fc4ba429b1df14ca81de8d6874ad838388177712da4f7f6b317b44).
The request hashes of all five demo suppliers from `requestHashFor` on v2 equal `api3/x402/requests.mjs`.

Reproduce (any judge, no wallet needed for the simulation):

```sh
export EVM_RPC_URL=https://ethereum-sepolia-rpc.publicnode.com PULSE_PLUS_ADDRESS=0xf25Aae1772326C95294D1923399D55c658493DfC
api3/scripts/plus-submit.sh 0 api3/fixtures/ch-03778796-202610301614.json          # genuine stale  -> StaleResponse
api3/scripts/plus-submit.sh 0 api3/fixtures/ch-07418033-202610301910.json          # genuine other  -> WrongRequest
api3/scripts/fetch-evidence.sh ch 03778796 me.json                                  # your own fresh record ($0.01 aUSD)
api3/scripts/plus-submit.sh 0 me.json                                               # -> ACCEPTED clean
for m in value stale request key; do api3/scripts/plus-submit.sh 0 me.json $m; done  # -> 4 rejections
```

Real reverted transactions (`--send`) for the video follow on Saturday, once Emre's wallet has Sepolia ETH.

## SupplierPulse+ autonomous agent (Julien, `api3/agent/`)

Agent wallet [`0xED3418aE93669a640650728E70f7aA712083253a`](https://sepolia.etherscan.io/address/0xED3418aE93669a640650728E70f7aA712083253a): it pays the gas on Ethereum Sepolia and the x402 fees in aUSD on Base Sepolia, and is never a buyer or a supplier. A paid check is one $0.01 aUSD x402 payment for a fresh signed Companies House record, then one contract transaction with that record. Schedule, limits and failure handling: `docs/agent.md`.

### v1 hedge run (live v1 contract, demo profile, since 30 Oct 17:03)

Contract [`0x91d7…74d7`](https://sepolia.etherscan.io/address/0x91d7dbae109029b2b1245179a68ac362799674d7) from "SupplierPulse live run" above. The agent re-checks each open order's supplier once per tier interval (10 min for Standard in the demo profile) and logs every cycle to `api3/agent/state/v1/cycles.jsonl`.

| Cycle | Time (CET) | Order / supplier | Why | Action | x402 payment (Base Sepolia) | Contract tx (Sepolia) | Outcome |
|---|---|---|---|---|---|---|---|
| 1 | 30 Oct 17:03:38 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0x9069fa…cf75`](https://sepolia.basescan.org/tx/0x9069fade4a8fe5f66b6e5458006953d82261649ba1337c3ef161cb389db4cf75) | [`0x1c8733…7bab`](https://sepolia.etherscan.io/tx/0x1c8733b6ee2140758cf31b8783afd3bff1c9cdada6c907779a0dcf8da6b27bab) | clean |
| 20 | 30 Oct 17:13:50 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0x40fc05…7031`](https://sepolia.basescan.org/tx/0x40fc05a3f9e88c1708cc36e153cc8bb1297f04d911ae2e058bd59cd9ec587031) | [`0x73bbe9…b932`](https://sepolia.etherscan.io/tx/0x73bbe9913af03ae62d80da3c7933b481b46f0649d8f6f781444c96c38737b932) | clean |
| 39 | 30 Oct 17:23:49 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0x237d9d…05c0`](https://sepolia.basescan.org/tx/0x237d9d02da086a85cefcbf7835a4a8ff94957223fde3ee85bdee5b6e84d705c0) | [`0x90135a…0e2b`](https://sepolia.etherscan.io/tx/0x90135a2c16f0a6a651530dbb06832be9453c6bd0dc3379b066043bd144240e2b) | clean |
| 59 | 30 Oct 17:34:26 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0xa7ae47…2612`](https://sepolia.basescan.org/tx/0xa7ae47d86ac2c198d7f4bd343edf1236aea6ebe0fa948a7992d4e5d574aa2612) | [`0x2dee76…5932`](https://sepolia.etherscan.io/tx/0x2dee762a376f4a34c3d12e782964bd1496eb3f97391e68f40035ead70e4d5932) | clean |
| 79 | 30 Oct 17:44:49 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0x4d7dcb…bef9`](https://sepolia.basescan.org/tx/0x4d7dcbea275c2f9af4cfeb4d56e5ffb590163bfe372866adb361c357cfecbef9) | [`0x301eed…9c4a`](https://sepolia.etherscan.io/tx/0x301eed19474732761791d76b6bf952f237ce0b9e27626f183b3557a242f39c4a) | clean |
| 99 | 30 Oct 17:55:13 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0x2a698b…93d4`](https://sepolia.basescan.org/tx/0x2a698b33884db2ea402ea89627fe497f03c8fa284528b6527927d5b1226893d4) | [`0xb4e30f…484c`](https://sepolia.etherscan.io/tx/0xb4e30f4a6dbd4fa261e1b8f6cebded439c2395b4dd1bd9d56b4bca335957484c) | clean |
| 119 | 30 Oct 18:05:37 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0x96c168…ebe7`](https://sepolia.basescan.org/tx/0x96c16869bad16e5a28a07be033f0dcc2d681661b14c59489cf7f0ab36060ebe7) | [`0x19e8d1…0492`](https://sepolia.etherscan.io/tx/0x19e8d106d92114e91124eb4527899220f8171f2f8432aace7cecbb6c4cd20492) | clean |
| 140 | 30 Oct 18:16:14 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0x5b486a…e7ca`](https://sepolia.basescan.org/tx/0x5b486a3834d6376a29abd8cd4ec0fdf1f6ba02e765454db930fefd591503e7ca) | [`0xf90491…d0f7`](https://sepolia.etherscan.io/tx/0xf9049107c93102a52a4e84f00f314fdb3506aa987934f5ff884fcbeaba33d0f7) | clean |

140 cycles from 30 Oct 17:03 to 30 Oct 18:16 (CET): 8 transactions, $0.08 spent on paid checks, 0 alerts, 0 errors. All other cycles had nothing due.

Generated with `AGENT_CONTRACT_VERSION=v1 python3 api3/agent/pulse_agent.py report --markdown`. The agent was restarted on the reviewed code at 18:09 (cycle 127) without a gap in the log. Cycle 140 is its first paid check on the new send path: gas limit 600,000, 205,073 used, success.

Checked on chain for cycle 59: the payment tx (a facilitator batch sent to Multicall3) contains an aUSD `Transfer` of 0.01 (`0x2710`, 6 decimals) from the agent wallet to the AirnodeHub payee `0x1505fd562ac2fb4307b85bc6c672ffeafb4d57a7`, and the contract tx succeeded on `0x91d7…74d7`.

### v2 run (SupplierPulse+ v2, demo profile, since 30 Oct 18:18)

Contract [`0xf25Aae1772326C95294D1923399D55c658493DfC`](https://sepolia.etherscan.io/address/0xf25Aae1772326C95294D1923399D55c658493DfC) (Orhun's C3 deploy). The agent started on it at 18:18 with no orders yet and acts on the demo orders as soon as they exist. Its transactions are added here at C4 with `python3 api3/agent/pulse_agent.py report --markdown`.

### C2 integration (local anvil, v1.1 contract, `api3/agent/c2_check.py`)

All six sample orders of `plus-local.sh` (§4.8), the agent at 10 s ticks, 8 checks on chain and in the agent log.

| When | Code | Fetch | Result |
|---|---|---|---|
| 30 Oct 17:22 | Orhun's v1.1 contract, `julien/plus-agent` | scratchpad v1.1 signer (stand-in) | 8/8 in 180 s. Found the bare-`0x` bug in calls without return values (fixed) |
| 30 Oct 17:39 | `supplierpulse-plus` `2b6ca9c` + `emre/plus-data` `8a1bedd` | Emre's `fetch-local.sh` | 8/8 in 181 s. Order 5: failed tries at +0, +31 and +158 s, then the no-data refund at the first tick after its refund time. Showed that monitoring could pay for a fetch on an order refunded in the same tick (fixed in `29d35c3`) |
| 30 Oct 17:45 | the same + `29d35c3` (monitoring fix) | Emre's `fetch-local.sh` | 8/8 in 181 s. Order 5 refunded after three failed tries; no waiting check logged twice |

### Commands

```sh
# v1 hedge on Sepolia, from the repo root. The key goes into the environment from a local, uncommitted .env.
export AGENT_CONTRACT_VERSION=v1 AGENT_PROFILE=demo PULSE_PLUS_ADDRESS=0x91d7dbae109029b2b1245179a68ac362799674d7
export EVM_RPC_URLS=https://ethereum-sepolia-rpc.publicnode.com,https://sepolia.gateway.tenderly.co
export AGENT_PRIVATE_KEY=<agent key> PAYER_PRIVATE_KEY=<agent key>     # never printed or committed
while true; do python3 api3/agent/pulse_agent.py run --quiet; echo "agent exited $?, restarting in 5 s"; sleep 5; done
AGENT_CONTRACT_VERSION=v1 python3 api3/agent/pulse_agent.py report      # cycles, spend, alerts

# C2 on a local chain (free local fetch, anvil keys only)
python3 api3/agent/c2_check.py            # --fake: the same 8 checks in memory
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
