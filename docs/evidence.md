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

### Outcomes (agent on v2, 30 Oct)

Read back on chain at 20:26 CET (`orderStatus`, `orderSchedule`, `cast logs` from block 12028630). Times are block times in CET.

- **A (0):** EvidenceAccepted + PermitIssued at 19:52:00 [`0xcb3a45…e82b`](https://sepolia.etherscan.io/tx/0xcb3a459159a23a2b67726085f4640227c268f94522f58a7ca832301ddf0de82b) and 20:02:24 [`0xe5c9b0…af5b`](https://sepolia.etherscan.io/tx/0xe5c9b01a4a3edeffa53f7fe2d0fda3fcea425316d1462f5335abbad198d8af5b). MilestonePaid m0, 500 tokens to `0x535d7e4d7f6c3B13F34da2aC98afE379912bed4a` at 20:03:48 (due 20:03:24), block 12028638, [`0xa03f3d…5587`](https://sepolia.etherscan.io/tx/0xa03f3d72700ce72ea7cdc6b9dac97dc28a3f43211549b3342321a8e14fe75587).
- **A (0), next milestone:** EvidenceAccepted + PermitIssued for m1 (1,000 tokens, permit valid until 20:42:42) and TierChanged 0 → 1 (clean streak 3) at 20:12:48, block 12028683, [`0xfe89bd…a382`](https://sepolia.etherscan.io/tx/0xfe89bdbb12e7feb8f9bed6bb3a6ec88d0cd72ca1b6f048346eb8624c38f8a382). m1 is due 31 Oct 11:45.
- **B (1):** held with `0x86` at 19:45:00 [`0x254f08…2323`](https://sepolia.etherscan.io/tx/0x254f08265550daf0c8de4d20fb29a3dd7310c9050e59339bb87f6d40b1742323); refunded 3,000 tokens to the buyer at 19:55:36 [`0x37bd28…cb3f`](https://sepolia.etherscan.io/tx/0x37bd28187b99b48c6f25f309ce7683232d1a9f7cbd313d38b9ff1fa36ed6cb3f).
- **C (2):** held with `0x02` at 19:45:48 [`0xbcc39c…d441`](https://sepolia.etherscan.io/tx/0xbcc39c8fc274c8674bac7b410b1cbc321cc1e82dc49640c7eabacbe8ed6dd441); refunded 1,000 tokens at 19:56:24 [`0x458093…0fd0`](https://sepolia.etherscan.io/tx/0x4580934a30754f43d9524e751fbc6c04ca443fd058e0a922400ba54fac250fd0).
- **D (3):** EvidenceAccepted + PermitIssued at 19:52:12 [`0x625af3…ba6c`](https://sepolia.etherscan.io/tx/0x625af3c442f1c12fa078f7a0e9b90c922de8b8d405fda05595b0cbf3dbb8ba6c) and 20:02:36 [`0x8e0a95…3c38`](https://sepolia.etherscan.io/tx/0x8e0a95b32ded431dea2432e3ae547029a2ac85da1f8c64c9d41865ef36c93c38).
- **D (3), new:** EvidenceAccepted + PermitIssued for m0 (500 tokens, permit valid until 20:42:50) and TierChanged 0 → 1 (clean streak 3) at 20:13:00, block 12028684, [`0xdb0cdc…d974`](https://sepolia.etherscan.io/tx/0xdb0cdc406b48b2102f93946edb6d4a8481c96d78aa666b292ae298337573d974).
- **D (3) paid:** MilestonePaid m0, 500 tokens to `0x535d7e4d7f6c3B13F34da2aC98afE379912bed4a` at 20:16:48 (due 20:16:12), block 12028703, [`0x7af6c9…37ef`](https://sepolia.etherscan.io/tx/0x7af6c99da9dd1bc3ef0479f3bae07342875e37f86d1d69de97667e61f45137ef). It used the evidence from the 20:13:00 record. Afterwards `orderStatus(3)` = active, paid 500, remaining 1,000, next milestone 1 of 2; `orderSchedule(3)` = next due 31 Oct 12:00, approved, tier 1.
- **E (4):** held with `0x08` at 19:48:12 [`0x0dbce4…9e3e`](https://sepolia.etherscan.io/tx/0x0dbce43cb2a1fdfc0ff20db3bb7a58eac80470cf651bd7095df0c5c7b8989e3e); refunded 1,000 tokens at 19:58:36 [`0xb617b1…2800`](https://sepolia.etherscan.io/tx/0xb617b152bd209fcf7f7cae7db112b2eac65994f580f31e7cc1cd8afa7f9f2800).
- The agent wallet `0xED3418aE93669a640650728E70f7aA712083253a` sent all evidence, payment and refund transactions. Refunds went to the buyer `0xEb3EB6da882798062b30CeC11AAaDe306287ce41`. No OrderRefunded or OrderHeld events since block 12028630.
- Source verification: Etherscan exact match (https://sepolia.etherscan.io/address/0xf25aae1772326c95294d1923399d55c658493dfc#code) and Sourcify exact match (https://sourcify.dev/server/verify-ui/jobs/4d49235a-c987-4166-8975-4ba46fa8926f), both from commit c668c51.

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
| 160 | 30 Oct 18:26:38 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0x0dd70e…e8fc`](https://sepolia.basescan.org/tx/0x0dd70e3175d5ed87b28385ea9bb80ddb236e61f1cd4572a1ffd304f8b6cce8fc) | [`0xdeba78…5093`](https://sepolia.etherscan.io/tx/0xdeba783b685688a609293cc0c54514f2c31e601b634bf4030177052b6a855093) | clean |
| 180 | 30 Oct 18:37:15 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0x7e9907…5395`](https://sepolia.basescan.org/tx/0x7e99079a36ce38a55b51c93f22800fe51e576d6387bccc71c367c1512cda5395) | [`0x757e8d…d60a`](https://sepolia.etherscan.io/tx/0x757e8d69bf5043cbc7845ffb8893a5ace177d3a41bc097be6da1ba9e1fdcd60a) | clean |
| 199 | 30 Oct 18:47:13 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0xdc5bb7…d808`](https://sepolia.basescan.org/tx/0xdc5bb7258a8eef267683b16892be22901a356705f3958413d697c2472fc8d808) | [`0xc285db…63e5`](https://sepolia.etherscan.io/tx/0xc285db8629980c95be757b458e6c6163531abc08939b81e78cfa781661b563e5) | clean |
| 219 | 30 Oct 18:57:39 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0x1f4a91…4cda`](https://sepolia.basescan.org/tx/0x1f4a91a97854aa211b919321d7c267029c1f992c1a5fdfcbe25633f89e544cda) | [`0xc22d03…e315`](https://sepolia.etherscan.io/tx/0xc22d034bac5511431a769005f663a1a33bab136259bb556a9de67beaf485e315) | clean |
| 239 | 30 Oct 19:08:01 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0x58160d…2418`](https://sepolia.basescan.org/tx/0x58160de90ece6a8b42c26782b42c50c1ed68e38bde0e56371f5adddcbed22418) | [`0x53c77a…c969`](https://sepolia.etherscan.io/tx/0x53c77a362e2d558ab5cb7d446e7b8432cdfb930c94c6fc573a9162e840a7c969) | clean |
| 259 | 30 Oct 19:18:28 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0xfa1d1f…549e`](https://sepolia.basescan.org/tx/0xfa1d1f84e69d41feda4603037121a8407363938df4def2221f1d19955346549e) | [`0x5e16c3…def5`](https://sepolia.etherscan.io/tx/0x5e16c36e84ab615d0f378a9a7e39b7c496947eea9ed67dd96a4d3fc76060def5) | clean |
| 279 | 30 Oct 19:29:01 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0x8ecf69…7067`](https://sepolia.basescan.org/tx/0x8ecf69109ce27b7b4bb2887350a45c75b4b0f856b8ac1d11d6ab1ad06ae67067) | [`0x6e9bff…29e7`](https://sepolia.etherscan.io/tx/0x6e9bffc10fdee9c49bd45a47f679a942e34854dee403515d1d111e60762b29e7) | clean |
| 299 | 30 Oct 19:39:27 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0xac8797…a8bc`](https://sepolia.basescan.org/tx/0xac8797b61e1223f800f889a5e1eda1c88e14ad7b4baa3ecf455ae7ad7d3ea8bc) | [`0x2b6402…0ec1`](https://sepolia.etherscan.io/tx/0x2b6402d808a134232f0997ede7e6b4da4d17e970ca2f7125320febb2e62c0ec1) | clean |
| 319 | 30 Oct 19:49:50 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0x7ebc42…0d54`](https://sepolia.basescan.org/tx/0x7ebc42b04a86e2d887220f8311d3ebd477806ab954a45c0fadabbbca15310d54) | [`0xefa6bf…c1f0`](https://sepolia.etherscan.io/tx/0xefa6bf92906fb829e205774a3cc48682123d9c94d8bcdc677444ff93fd09c1f0) | clean |
| 339 | 30 Oct 20:00:14 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0x92b639…496e`](https://sepolia.basescan.org/tx/0x92b6394b73c603d1fa4c7c5fdaac1ae59e8d97ee313be1c5a88524cda71c496e) | [`0x2baada…51ec`](https://sepolia.etherscan.io/tx/0x2baada41efbeeb9160d5da3df5abb92da16e24222d98255075909e18665151ec) | clean |
| 359 | 30 Oct 20:10:39 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0x6c2024…b8e3`](https://sepolia.basescan.org/tx/0x6c202415c59793370594e68ceb151bf0f8662cb2c7af8cf993ba605f5cefb8e3) | [`0xef2926…c301`](https://sepolia.etherscan.io/tx/0xef2926f724146f486612e9f8d3f500ec6195bb45050ac4ba2df3d193607ac301) | clean |
| 379 | 30 Oct 20:21:15 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0xf226ab…8fce`](https://sepolia.basescan.org/tx/0xf226aba7b8439f6f6c57e9a6b3676ff420f34264643b55fe1b89a6e787728fce) | [`0x29686d…cd5f`](https://sepolia.etherscan.io/tx/0x29686debbc3c2385d3c699911cb3f51c4242f5e5c251c05bf81a37ff8fdacd5f) | clean |
| 399 | 30 Oct 20:31:38 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0x296edc…461f`](https://sepolia.basescan.org/tx/0x296edca2fd1de6eef8d4d64c711a6a16922214cf62ea479647263bc8f015461f) | [`0xe0084c…8d89`](https://sepolia.etherscan.io/tx/0xe0084c50d803b678ac989337837e15e7a0db5fb730905432787aa5eb4e988d89) | clean |
| 419 | 30 Oct 20:42:01 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0xb1363f…2081`](https://sepolia.basescan.org/tx/0xb1363f843f8e5ac2e8639a3823850c799cfda33849c684ada850ea0488762081) | [`0x70bb7f…5aa1`](https://sepolia.etherscan.io/tx/0x70bb7f2e6f879814ef69234e8c0f046aad58707054c56d54aed93d166e995aa1) | clean |
| 439 | 30 Oct 20:52:25 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0xeedf30…79b5`](https://sepolia.basescan.org/tx/0xeedf30a3b8391449126402e6003ea33885e539bbf58077d4a1fcc38e687479b5) | [`0xb21b2d…8e19`](https://sepolia.etherscan.io/tx/0xb21b2d0f39a60e829b298655340219e8569476c4437ede138af45218db538e19) | clean |
| 459 | 30 Oct 21:02:51 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0xe2f194…a804`](https://sepolia.basescan.org/tx/0xe2f194e4964481134b9a7634f55abc75df0ae088c981b8df7652e0b5ebd9a804) | [`0x175eed…2a73`](https://sepolia.etherscan.io/tx/0x175eedc9ed0235963e14d91138950785e5b691b41275a8877667c912525c2a73) | clean |
| 479 | 30 Oct 21:13:14 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0xc465b1…d75e`](https://sepolia.basescan.org/tx/0xc465b17401bd1c90b576285463cb606d35f77213ade72730621c7c6bf758d75e) | [`0x976e4a…0278`](https://sepolia.etherscan.io/tx/0x976e4a9bb8ee829cf92177b76d05f15c1832d258428a6c5d78e7b16ce8cc0278) | clean |
| 499 | 30 Oct 21:23:48 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0x1e5ae9…76ec`](https://sepolia.basescan.org/tx/0x1e5ae90a90bb5babd65d03382fa61ddbd45f381007d9d47ad1f05ed8534f76ec) | [`0x9d1af7…c5b2`](https://sepolia.etherscan.io/tx/0x9d1af79f9a772c63a14ce4e339bba45b9ebddd6ce3e70cb970b57b0f9784c5b2) | clean |
| 519 | 30 Oct 21:34:13 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0xaa7c16…cb92`](https://sepolia.basescan.org/tx/0xaa7c16465bd5639b668d4b1a46a0be79cf0b482a2be06d419dbd7cd2cfe1cb92) | [`0x62df7b…c381`](https://sepolia.etherscan.io/tx/0x62df7b4152413ea91780632da6d60ab60eda2698dc79510d6b99b9bb1e4ec381) | clean |
| 540 | 30 Oct 21:45:14 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0x2d8b36…71b1`](https://sepolia.basescan.org/tx/0x2d8b3677bfe0ba727197900f7107455c9581fe982b0ec5ea4060870e472071b1) | [`0x3dfc9b…d293`](https://sepolia.etherscan.io/tx/0x3dfc9b36a7a9e74f9bf727c4bbe1a9156e49d3f05bd06f6693d4ac1c7216d293) | clean |
| 560 | 30 Oct 21:55:36 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0xafb2c9…d65a`](https://sepolia.basescan.org/tx/0xafb2c9a4847bbcca072d0b40d2c978287ab9258e50ebf81034814135093dd65a) | [`0x39118e…2517`](https://sepolia.etherscan.io/tx/0x39118ec1eae98de0fdde0752f752f5471ddb5e5b53125954d078263094372517) | clean |
| 580 | 30 Oct 22:06:03 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0x82e127…04ef`](https://sepolia.basescan.org/tx/0x82e127247cb2c144f61af20739e2a7bdf265ae177c38bdd217a794d9c9ec04ef) | [`0x4a70d6…06e5`](https://sepolia.etherscan.io/tx/0x4a70d6f947afdf2282075f8d0e483b3fb64da6ad594053e404559578de5806e5) | clean |
| 600 | 30 Oct 22:16:51 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0x95b922…f59c`](https://sepolia.basescan.org/tx/0x95b922343f65533ecf778029c0b8438121c687c423e938713d54a5ca1fa6f59c) | [`0x23a36c…5aa5`](https://sepolia.etherscan.io/tx/0x23a36cf6be52f56cde72b419f4a6e4490ef86642200b3a076bddd9aabfee5aa5) | clean |
| 619 | 30 Oct 22:26:50 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0x4a62c2…fc41`](https://sepolia.basescan.org/tx/0x4a62c2e40410a4f6134670a61062f978f3bccc0adee4c614017b566b8986fc41) | [`0x26812f…81dc`](https://sepolia.etherscan.io/tx/0x26812fc13304f29fc7bc1522ed3db3e16ad2e32009bdf7354964b9ff325681dc) | clean |
| 639 | 30 Oct 22:37:14 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0x55f6c0…427f`](https://sepolia.basescan.org/tx/0x55f6c0eb7c4847cf2e91bd78f89def2ab45bccd5def85c6ff915061ad232427f) | [`0x160e47…ef16`](https://sepolia.etherscan.io/tx/0x160e47fd9debce8c34505697dfd73065d7cc5ef0029a613ca40543a2c2a2ef16) | clean |
| 659 | 30 Oct 22:47:38 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0x345abc…6234`](https://sepolia.basescan.org/tx/0x345abcb8774eea9e1333a236646d9b15608cc0c87edb5838ab19f3798efc6234) | [`0x4bba82…60a2`](https://sepolia.etherscan.io/tx/0x4bba820690b691afbdbf97aaf584822a448a2cdd9b47048c5a8f4a92ff5c60a2) | clean |
| 679 | 30 Oct 22:58:02 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0x43fbb0…a6ca`](https://sepolia.basescan.org/tx/0x43fbb0e9887ba3887dd009a72c8ca09250aed349119d997ff7b352555af7a6ca) | [`0xdccbfe…598d`](https://sepolia.etherscan.io/tx/0xdccbfee5774e0625f3f517113d723db1ae5c3048bf71b82cf22926350bf0598d) | clean |
| 699 | 30 Oct 23:08:26 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0xf8946d…be03`](https://sepolia.basescan.org/tx/0xf8946d9a0eb2d0030f0010ad4ab7525c888a6fdbd1cb3dfce41fd5cf0973be03) | [`0x81974a…aa42`](https://sepolia.etherscan.io/tx/0x81974a90a1facc3264e86a5b6ef62a59858e48aec88ba3a52ce76fde499caa42) | clean |
| 719 | 30 Oct 23:18:50 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0x081d0d…97a8`](https://sepolia.basescan.org/tx/0x081d0ddc276390cb09d0842a389746fb0b51ca7dfc792522583d6c5cd47a97a8) | [`0xf25559…6f49`](https://sepolia.etherscan.io/tx/0xf25559dbadb46e010b03f5ded0f5aa8fa34f8db9b20af7649a5b49eafcd66f49) | clean |
| 739 | 30 Oct 23:29:14 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0x280f53…fe1d`](https://sepolia.basescan.org/tx/0x280f531bd72d38aa946bef7e37c524e0af9ba0a78616b1d6095bd962aab7fe1d) | [`0x9883fe…1b9b`](https://sepolia.etherscan.io/tx/0x9883fee779106d3d67ea68641d6fb02e96ec0a7087a64e5fffc50bcc94d51b9b) | clean |
| 759 | 30 Oct 23:39:38 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0x368b7e…286a`](https://sepolia.basescan.org/tx/0x368b7e34bdaca6f309f893e15aee9e84108d27f73502761d53f803d7b60d286a) | [`0x5216a4…fe64`](https://sepolia.etherscan.io/tx/0x5216a451d646aa6175c80c46771d0604abce64ddd4162a2556bb80de4168fe64) | clean |
| 779 | 30 Oct 23:50:03 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0x03ef4d…f436`](https://sepolia.basescan.org/tx/0x03ef4d76b7d92310243ba5d81d1a9784d258c956846f3ef53111ce56fb02f436) | [`0xd31fd9…a7ca`](https://sepolia.etherscan.io/tx/0xd31fd90fc6f86a57ef83818a0b9ffd23d3412f367bfa1a8e9bc7df44ff77a7ca) | clean |
| 799 | 31 Oct 00:00:26 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0xc48a51…963f`](https://sepolia.basescan.org/tx/0xc48a51fff12955c4547383ee171b32cd4ce4f29c238631049dd18adfa7a8963f) | [`0xb56adf…b8ad`](https://sepolia.etherscan.io/tx/0xb56adf7e4fa9acba2a30dbd494d287844c4d25a2bb36d2821f7f34ca1ec7b8ad) | clean |
| 819 | 31 Oct 00:11:01 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0x86cef7…3880`](https://sepolia.basescan.org/tx/0x86cef7f0b116a89b18f76750068a86cf59ebadec80f5bbbda16e8f3422373880) | [`0xbd4580…5f5b`](https://sepolia.etherscan.io/tx/0xbd458090dc050b7c6fdcca0031319439666bbeb58934dea8a3d0fd032a845f5b) | clean |
| 839 | 31 Oct 00:21:28 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0x25edc6…7e5b`](https://sepolia.basescan.org/tx/0x25edc66393b8d0d6e856f7d2b8fc872ec92ded651f27c9d6c4097e0c98ec7e5b) | [`0x3b4909…8679`](https://sepolia.etherscan.io/tx/0x3b49098869e1fc1d8821adc1028bc2ef9b344e492198e6aaef75ac66f70c8679) | clean |
| 860 | 31 Oct 00:32:25 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0xcc176c…7390`](https://sepolia.basescan.org/tx/0xcc176cd477277b30c619e1b457bf1c57ea19eeca3d689b356c1ad98214277390) | [`0x2bb790…afad`](https://sepolia.etherscan.io/tx/0x2bb790ceb1891e702a55e35b06e9f678a7a0311583025d63246071ec9ccfafad) | clean |
| 875 | 31 Oct 00:45:36 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0x0f721b…cfd8`](https://sepolia.basescan.org/tx/0x0f721b9e2227bead590893fb4aa6eb52fc11581ee73f7cffbb11cfeeb816cfd8) | [`0x637f20…d475`](https://sepolia.etherscan.io/tx/0x637f20ed7541389f0b91f94f0080d4d63640be9dcc8ed0a5a174e105507dd475) | clean |
| 895 | 31 Oct 00:56:04 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0x97f630…5030`](https://sepolia.basescan.org/tx/0x97f6305a4baee4a1d61902ef04b285df01bb996bcd4dfd2e8fd2bad63d995030) | [`0x56e13e…9872`](https://sepolia.etherscan.io/tx/0x56e13e2a8d7b6a593d959d19cdcb5ff32765caee44c834cb50527fff48e79872) | clean |
| 915 | 31 Oct 01:06:37 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0xe1eb1d…01c0`](https://sepolia.basescan.org/tx/0xe1eb1d4247f81785cfcb716cfc49c3964635484e142417fe9c47e41ee96001c0) | [`0x022299…cbb5`](https://sepolia.etherscan.io/tx/0x02229903a4166e39b93ab0c4e18de277c29b4d713022f2b7fd49a5f18cf0cbb5) | clean |
| 935 | 31 Oct 01:17:02 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0xe2fc49…b4af`](https://sepolia.basescan.org/tx/0xe2fc499a8c027c4439794fb9ebebcfdc69ae45586eb0123cc1e91e8142f5b4af) | [`0x2cccd0…fe5d`](https://sepolia.etherscan.io/tx/0x2cccd01f6b26b80b43958812beb82295251afde85f954d4d769e2520a146fe5d) | clean |
| 955 | 31 Oct 01:27:26 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0x88a38a…a1ba`](https://sepolia.basescan.org/tx/0x88a38a1b8269465dc2f0f59f8d3b778997868a5f49eead25cfa0c73c07eea1ba) | [`0x7450d8…a1f0`](https://sepolia.etherscan.io/tx/0x7450d8fe6ad823d1e9c5adca20465ac617357d9ef683ca03cf69b49d1c94a1f0) | clean |
| 975 | 31 Oct 01:38:03 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0x946633…4a40`](https://sepolia.basescan.org/tx/0x9466337b545a772251f52ca0ca2dd39ea986d659390c8cbc35f574d1c5024a40) | [`0xfb3737…90e7`](https://sepolia.etherscan.io/tx/0xfb37370fa37a5f6eddb167e5564bbf19c704ee8f8d0c5a4c7ad1eb3a4b3b90e7) | clean |
| 995 | 31 Oct 01:48:26 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0xc9d8ba…9fe5`](https://sepolia.basescan.org/tx/0xc9d8ba1955899273808cf665591ffd09edece0289b389122731b1b5051df9fe5) | [`0x4f36ca…38a3`](https://sepolia.etherscan.io/tx/0x4f36ca0e154c166e281a55dd6a60015eb088f38fc6bc0f006b9ab68959f638a3) | clean |
| 1015 | 31 Oct 01:58:51 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0xab6850…2ba0`](https://sepolia.basescan.org/tx/0xab685025061d51f0bdf8082e19dee1b7d1a7c2fead1656bd7eb9092d34022ba0) | [`0x4d8f9f…8e46`](https://sepolia.etherscan.io/tx/0x4d8f9f5c594bfa2914b3a56a3c5fb93b1114fb33729978e8ff4710d0343b8e46) | clean |
| 1035 | 31 Oct 02:09:13 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0xc515bd…c1da`](https://sepolia.basescan.org/tx/0xc515bdc36df2641a61e5e6827b4b72b20966bd6a8cdc7eafc047d808077ec1da) | [`0xb958af…029c`](https://sepolia.etherscan.io/tx/0xb958af4ae403df2f88d97b3c2b5b9d1a32d89ecc22b620f32a52161eef9e029c) | clean |
| 1053 | 31 Oct 04:05:51 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0x4131da…045b`](https://sepolia.basescan.org/tx/0x4131dac8e3eff9e5bbe1ef09390c9fcf773aea24b2204e1e36a925563787045b) | [`0x22da8c…08dd`](https://sepolia.etherscan.io/tx/0x22da8cffd5a71ebc7253a83bd34f62f1899c9dc660356ff96a5e10c88c4708dd) | clean |
| 1054 | 31 Oct 05:37:06 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0x6a8667…dcc8`](https://sepolia.basescan.org/tx/0x6a86675b83876d861b628a15d54a6af0ca52f9d57a224e524827190938d8dcc8) | [`0xae26a4…85aa`](https://sepolia.etherscan.io/tx/0xae26a484cf9efe7ef40897ab2bfad3c2398623e3827f13f12a15d4d4081b85aa) | clean |
| 1055 | 31 Oct 07:09:41 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0xde5340…f7ed`](https://sepolia.basescan.org/tx/0xde53409e71f45f1c30f92a5cf02d7e50b6764320ff9ee12546e1903f9dc6f7ed) | [`0x0b12bf…2724`](https://sepolia.etherscan.io/tx/0x0b12bf1fbf78ce9b8e0d39e258e997fd304404e7bfc7970982e817e6a89d2724) | clean |
| 1056 | 31 Oct 08:38:43 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0x9249fd…1a95`](https://sepolia.basescan.org/tx/0x9249fdfc2356f1e7d7bf5f0788e4e67f01579042e674d57fd4909b21a67a1a95) | [`0x07de3d…edc8`](https://sepolia.etherscan.io/tx/0x07de3ddbdd12cff2354c2ef4e8641466594cbaf704cfdc692889794c5593edc8) | clean |
| 1057 | 31 Oct 09:26:15 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0x8539ba…594f`](https://sepolia.basescan.org/tx/0x8539ba2dfac793f9157110019c916e0fcef6fedf2e59917560a2442b5033594f) | [`0x8f288c…5ae8`](https://sepolia.etherscan.io/tx/0x8f288cc1eafda6506b378ebb48fe13cd5c091fd3dcbd52c2b7e0baa9a0015ae8) | clean |
| 1077 | 31 Oct 09:36:38 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0x81d53c…c384`](https://sepolia.basescan.org/tx/0x81d53c8fefaeb8947caff594c53ad816c393885c400b77ccd6290e426f0cc384) | [`0xf770ba…b0ed`](https://sepolia.etherscan.io/tx/0xf770baba517752831f7d7b66e7afc7ca3082df330baf2d2881a977330fbdb0ed) | clean |
| 1097 | 31 Oct 09:47:03 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0x6e22a4…9a63`](https://sepolia.basescan.org/tx/0x6e22a48886eec989f265fc0ccb6b2832231ba5900bf78729c1756e1a6df49a63) | [`0x907206…12ed`](https://sepolia.etherscan.io/tx/0x907206e9fc303a507bf9ea8f5e8f4da8372fa4e5e16ea4b4d7eece3ed33912ed) | clean |
| 1117 | 31 Oct 09:57:25 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0x099f06…1eb0`](https://sepolia.basescan.org/tx/0x099f06f2e8ff21a31164cb0e478a76639026e7737a84379f2909ca782b371eb0) | [`0xa51705…5f87`](https://sepolia.etherscan.io/tx/0xa517055820a2db63b241679e29e70bd99461f80c165b24ee8dcbbce8a8f75f87) | clean |
| 1137 | 31 Oct 10:07:50 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0x7d9b5b…476f`](https://sepolia.basescan.org/tx/0x7d9b5be3020959f354c106f72575fcd8a1f690825f26db7e35831687c1d4476f) | [`0xf57cfa…3df3`](https://sepolia.etherscan.io/tx/0xf57cfad372e22b05e0d5ebb948e6b2560db4b01bbf2e449e10106edca8e83df3) | clean |
| 1157 | 31 Oct 10:18:14 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0xf30fcc…0d6a`](https://sepolia.basescan.org/tx/0xf30fcc5f31165a615b375897f73218ea311e21579b618013b09fdff6617f0d6a) | [`0x310f39…25a3`](https://sepolia.etherscan.io/tx/0x310f391c04d4f4fd29773bb48aa9f3dbacc310fc51cf87066fe7abfa4cd725a3) | clean |
| 1177 | 31 Oct 10:28:38 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0xb3e1d6…4d20`](https://sepolia.basescan.org/tx/0xb3e1d6d2c9ae4eacccf21998932a860502e17993b1a0fffecb789e4fb4f24d20) | [`0x3c2b97…0443`](https://sepolia.etherscan.io/tx/0x3c2b97add304948d9156c2ebde2a4f0bf2905c7cda0ab6b5c896294701960443) | clean |
| 1197 | 31 Oct 10:39:03 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0x9fdc1f…e3e1`](https://sepolia.basescan.org/tx/0x9fdc1f426b4f2e0faeb3b80616f7a248ab4fccb961e90d85093de3ecc9c4e3e1) | [`0x40c162…3cc3`](https://sepolia.etherscan.io/tx/0x40c1622e04573496988408b9aea53e26f7129966eaa98be8bd58b17f51c93cc3) | clean |
| 1217 | 31 Oct 10:49:27 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0x68447e…c5c6`](https://sepolia.basescan.org/tx/0x68447e381820aa441d2b531e1510638e5292021d45543dc6e09000af7365c5c6) | [`0xc20ca7…630f`](https://sepolia.etherscan.io/tx/0xc20ca7866423d6dfe74aeabbac3915981078fd3830edda6ba8f1c313005e630f) | clean |
| 1237 | 31 Oct 10:59:51 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0xdb1751…28c4`](https://sepolia.basescan.org/tx/0xdb17512035e384dd945e11d4cdd0ca037d33fe92c67755242199301390f828c4) | [`0xe57ff5…d360`](https://sepolia.etherscan.io/tx/0xe57ff5c841304c702fde900a02e542a14e77ce1af0b4505aa7d31aae833cd360) | clean |
| 1257 | 31 Oct 11:10:15 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0xb47627…e738`](https://sepolia.basescan.org/tx/0xb47627040a989d0dce32d40b676c7931aebc95e44bd6e151197ca86d2639e738) | [`0x0ab99b…9d20`](https://sepolia.etherscan.io/tx/0x0ab99b12da6e2eeca6448188fcf04e4b2468338da9d34c7a2cfd697b3d259d20) | clean |
| 1277 | 31 Oct 11:20:39 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0xa96d3f…d522`](https://sepolia.basescan.org/tx/0xa96d3f3ee5bcb5bfcd006d1a177bc765edf0e22ecdf348aad587a29a3311d522) | [`0x6a687d…4446`](https://sepolia.etherscan.io/tx/0x6a687dc27c0c76a409a3eb69d6b7b5e106e453f407491418cdc7b04bd9c24446) | clean |
| 1297 | 31 Oct 11:31:03 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0xc411d4…69c7`](https://sepolia.basescan.org/tx/0xc411d4df0052e68c9797da2e7f67600794b177705c076b6936352b7b046369c7) | [`0xc1cd69…882e`](https://sepolia.etherscan.io/tx/0xc1cd6905bcc20c76ec5f429a8d53a014fefc561e9464b0091287ebe1baf8882e) | clean |
| 1317 | 31 Oct 11:41:26 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0xadcdfe…5648`](https://sepolia.basescan.org/tx/0xadcdfe43a640dd27c1ae3c1d975849548964fe2711cd66b023af5c8555c35648) | [`0x4d01cb…128b`](https://sepolia.etherscan.io/tx/0x4d01cb23c74e3a80403c54dedef2304d44877b1122825359cc64437533ff128b) | clean |
| 1337 | 31 Oct 11:51:49 | 0 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0x29343a…bfba`](https://sepolia.basescan.org/tx/0x29343a5084d4fd7368977d51cea4f148d24f82062e3ce2e2c126d8b504e5bfba) | [`0xef4a8f…6687`](https://sepolia.etherscan.io/tx/0xef4a8fcb39f69677759b6281f4acd59c9f80ae337633d763db0e7f2295bf6687) | clean |

1355 cycles from 30 Oct 17:03 to 31 Oct 12:01 (CET): 72 transactions, $0.73 spent on paid checks, 0 alerts, 3 errors.

Generated with `AGENT_CONTRACT_VERSION=v1 python3 api3/agent/pulse_agent.py report --markdown`. The agent was restarted on the reviewed code at 18:09 (cycle 127) without a gap in the log. Cycle 140 is its first paid check on the new send path: gas limit 600,000, 205,073 used, success.

Checked on chain for cycle 59: the payment tx (a facilitator batch sent to Multicall3) contains an aUSD `Transfer` of 0.01 (`0x2710`, 6 decimals) from the agent wallet to the AirnodeHub payee `0x1505fd562ac2fb4307b85bc6c672ffeafb4d57a7`, and the contract tx succeeded on `0x91d7…74d7`.

### v2 run (SupplierPulse+ v2, demo profile, since 30 Oct 18:18)

Contract [`0xf25Aae1772326C95294D1923399D55c658493DfC`](https://sepolia.etherscan.io/address/0xf25Aae1772326C95294D1923399D55c658493DfC) (Orhun's C3 deploy, demo orders A–E = ids 0–4). The agent started on it at 18:18, before the orders existed, and took them up by itself.

**Sepolia acceptance (§6.3): passed at 20:17**, `python3 api3/agent/c3_check.py`:
- A M1 paid by the agent at 20:03:52, 28 s after its due date, on the permit from its own re-check at 20:02;
- D M1 paid by the agent at 20:16:52;
- B held at its first check (`0x86`: status, accounts, confirmation statement) and refunded by the agent when the grace period ended;
- C held (`0x02`, accounts overdue) and E held (`0x08`, LEI lapsed), both refunded after their grace periods;
- A's supplier rose from Standard to Trusted at 20:13 (3 clean checks, each counted at least 300 s apart);
- 226 autonomous cycles by 20:17.

Not hidden: before 19:51, 6 sends for the clean records of A and D ran out of gas at the 600k limit (clean v2 records need ~680k). After the limit was raised to 2,000,000 they went through (PROGRESS, `9a0d4d7`).

| Cycle | Time (CET) | Order / supplier | Why | Action | x402 payment (Base Sepolia) | Contract tx (Sepolia) | Outcome |
|---|---|---|---|---|---|---|---|
| 171 | 30 Oct 19:45:03 | 1 / `ch:07418033` | re-check by tier | `submitEvidence` | [`0x26d821…8121`](https://sepolia.basescan.org/tx/0x26d8212944cdc1dd8a7965de06e2c45c9a59b29fa8d4bd391633058133ea8121) | [`0x254f08…2323`](https://sepolia.etherscan.io/tx/0x254f08265550daf0c8de4d20fb29a3dd7310c9050e59339bb87f6d40b1742323) | held |
| 172 | 30 Oct 19:45:50 | 2 / `ch:09729896` | re-check by tier | `submitEvidence` | [`0x4fdcb6…f0ff`](https://sepolia.basescan.org/tx/0x4fdcb6b7c938ba22920ffa82b0fd786ae8d7296ee49deae12a01e710c54ff0ff) | [`0xbcc39c…d441`](https://sepolia.etherscan.io/tx/0xbcc39c8fc274c8674bac7b410b1cbc321cc1e82dc49640c7eabacbe8ed6dd441) | held |
| 175 | 30 Oct 19:48:16 | 4 / `gleif:52990092KBQJF8QBGJ50` | re-check by tier | `submitEvidence` | [`0x89138d…2c08`](https://sepolia.basescan.org/tx/0x89138dd3d28e7a7efb33248f85d20a02a2c863bdf167eeffe909bf4ad1002c08) | [`0x0dbce4…9e3e`](https://sepolia.etherscan.io/tx/0x0dbce43cb2a1fdfc0ff20db3bb7a58eac80470cf651bd7095df0c5c7b8989e3e) | held |
| 182 | 30 Oct 19:52:01 | 0 / `ch:03778796` | re-check by tier | `submitEvidence` | [`0x1ec42c…2aaf`](https://sepolia.basescan.org/tx/0x1ec42c9e8e9b8251cc6a70e902548431fb8efc16fc810993f747f87eaefc2aaf) | [`0xcb3a45…e82b`](https://sepolia.etherscan.io/tx/0xcb3a459159a23a2b67726085f4640227c268f94522f58a7ca832301ddf0de82b) | clean |
| 182 | 30 Oct 19:52:16 | 3 / `gleif:391200JI69LS8L648F30` | re-check by tier | `submitEvidence` | [`0x7a96e0…4c19`](https://sepolia.basescan.org/tx/0x7a96e008c6a695bee2c63fcab068a2f4be1191fc338d08a4e6cd1503aa864c19) | [`0x625af3…ba6c`](https://sepolia.etherscan.io/tx/0x625af3c442f1c12fa078f7a0e9b90c922de8b8d405fda05595b0cbf3dbb8ba6c) | clean |
| 188 | 30 Oct 19:55:39 | 1 / `ch:07418033` | grace period over | `refundRemaining` | – | [`0x37bd28…cb3f`](https://sepolia.etherscan.io/tx/0x37bd28187b99b48c6f25f309ce7683232d1a9f7cbd313d38b9ff1fa36ed6cb3f) | Refunded |
| 189 | 30 Oct 19:56:24 | 2 / `ch:09729896` | grace period over | `refundRemaining` | – | [`0x458093…0fd0`](https://sepolia.etherscan.io/tx/0x4580934a30754f43d9524e751fbc6c04ca443fd058e0a922400ba54fac250fd0) | Refunded |
| 193 | 30 Oct 19:58:38 | 4 / `gleif:52990092KBQJF8QBGJ50` | grace period over | `refundRemaining` | – | [`0xb617b1…2800`](https://sepolia.etherscan.io/tx/0xb617b152bd209fcf7f7cae7db112b2eac65994f580f31e7cc1cd8afa7f9f2800) | Refunded |
| 200 | 30 Oct 20:02:24 | 0 / `ch:03778796` | re-check by tier | `submitEvidence` | [`0x6269c0…2852`](https://sepolia.basescan.org/tx/0x6269c04c8fb582affdd0e896082b563f130940874499d31c58ccb5188ccb2852) | [`0xe5c9b0…af5b`](https://sepolia.etherscan.io/tx/0xe5c9b01a4a3edeffa53f7fe2d0fda3fcea425316d1462f5335abbad198d8af5b) | clean |
| 200 | 30 Oct 20:02:39 | 3 / `gleif:391200JI69LS8L648F30` | re-check by tier | `submitEvidence` | [`0x2d872a…fc7f`](https://sepolia.basescan.org/tx/0x2d872a061f181d49ebe1e01597dfc07af79451b4a4e4149436e1f997ac0bfc7f) | [`0x8e0a95…3c38`](https://sepolia.etherscan.io/tx/0x8e0a95b32ded431dea2432e3ae547029a2ac85da1f8c64c9d41865ef36c93c38) | clean |
| 202 | 30 Oct 20:03:52 | 0 / `ch:03778796` | milestone due | `release` | – | [`0xa03f3d…5587`](https://sepolia.etherscan.io/tx/0xa03f3d72700ce72ea7cdc6b9dac97dc28a3f43211549b3342321a8e14fe75587) | Paid |
| 219 | 30 Oct 20:12:49 | 0 / `ch:03778796` | re-check by tier | `submitEvidence` | [`0x9ede09…47a8`](https://sepolia.basescan.org/tx/0x9ede09d8efaf53358f4fb79f81b269a5e93497b678b9a49d01773967893647a8) | [`0xfe89bd…a382`](https://sepolia.etherscan.io/tx/0xfe89bdbb12e7feb8f9bed6bb3a6ec88d0cd72ca1b6f048346eb8624c38f8a382) | clean |
| 219 | 30 Oct 20:13:01 | 3 / `gleif:391200JI69LS8L648F30` | re-check by tier | `submitEvidence` | [`0x410a56…09cf`](https://sepolia.basescan.org/tx/0x410a561ff2f1043edf780afb1db2ce6b3c88427140770e7f5123a70b432909cf) | [`0xdb0cdc…d974`](https://sepolia.etherscan.io/tx/0xdb0cdc406b48b2102f93946edb6d4a8481c96d78aa666b292ae298337573d974) | clean |
| 226 | 30 Oct 20:16:52 | 3 / `gleif:391200JI69LS8L648F30` | milestone due | `release` | – | [`0x7af6c9…37ef`](https://sepolia.etherscan.io/tx/0x7af6c99da9dd1bc3ef0479f3bae07342875e37f86d1d69de97667e61f45137ef) | Paid |
| 277 | 30 Oct 20:43:25 | 0 / `ch:03778796` | re-check by tier | `submitEvidence` | [`0x1d9f88…d0c7`](https://sepolia.basescan.org/tx/0x1d9f887d2fde6f32cd9244a1b08be5bb91cdafb1dacdd1734b5ace4fb4f9d0c7) | [`0x69946b…5e09`](https://sepolia.etherscan.io/tx/0x69946b34bbcc106af19db873d5cbe1a9f5564295a0c13082df11719afff45e09) | clean |
| 277 | 30 Oct 20:43:50 | 3 / `gleif:391200JI69LS8L648F30` | re-check by tier | `submitEvidence` | [`0xabb840…eec6`](https://sepolia.basescan.org/tx/0xabb84090fac0b2fc9343aa20a79d20f026ac8677e5fcd2827d7ac9eda64eeec6) | [`0x95cef1…a81e`](https://sepolia.etherscan.io/tx/0x95cef1c98da423abe2551b7966be95e5eb911f88be8dc8c86ae0e497adeaa81e) | clean |
| 335 | 30 Oct 21:14:15 | 0 / `ch:03778796` | re-check by tier | `submitEvidence` | [`0xc5d94c…1610`](https://sepolia.basescan.org/tx/0xc5d94c24d0bdfe4b233808bba08898bbaffcf8742f829f6420689bbd68511610) | [`0xab9d3d…49c6`](https://sepolia.etherscan.io/tx/0xab9d3d76ea278f9b330319def49de1d7460eb5a07eba09c3c888807136ec49c6) | clean |
| 335 | 30 Oct 21:14:26 | 3 / `gleif:391200JI69LS8L648F30` | re-check by tier | `submitEvidence` | [`0xf448c1…51ef`](https://sepolia.basescan.org/tx/0xf448c1755b025905f4f84e939b842d5e6a9f76db03f0df67738d5892300451ef) | [`0x483ebc…ba39`](https://sepolia.etherscan.io/tx/0x483ebc07b6ad7084127348c4ca35cbca8ddd5201e7aa1224b4e8d3d089c7ba39) | clean |
| 393 | 30 Oct 21:44:38 | 0 / `ch:03778796` | re-check by tier | `submitEvidence` | [`0x758627…1f00`](https://sepolia.basescan.org/tx/0x758627a0bf5b9085f38ba617f8ae3aad4befbbfbc89dd49110c5b5a8d8bf1f00) | [`0x1db9b0…d90a`](https://sepolia.etherscan.io/tx/0x1db9b000bf5a599b6f600d32c939d6a9f599735aae170f3bcea41c4ac5ead90a) | clean |
| 393 | 30 Oct 21:44:50 | 3 / `gleif:391200JI69LS8L648F30` | re-check by tier | `submitEvidence` | [`0x6b63d1…1a8e`](https://sepolia.basescan.org/tx/0x6b63d13abaf858a9957036c4fe3f370b37e60e306506ff06eecba8a4a8841a8e) | [`0x6ed628…8cb0`](https://sepolia.etherscan.io/tx/0x6ed628a40420826356060532dba60c7b4363a36b8ad48116b9e89e73a1e58cb0) | clean |
| 509 | 30 Oct 22:44:51 | 0 / `ch:03778796` | re-check by tier | `submitEvidence` | [`0x7e0371…9aed`](https://sepolia.basescan.org/tx/0x7e0371e4497ce53e9c557b711a68bd2f958494730690479a201b0b0c0b6b9aed) | [`0x30a297…6670`](https://sepolia.etherscan.io/tx/0x30a2979012f69efe208c9a368cea6f7118c7f92ec6dbe53960229447f4e96670) | clean |
| 510 | 30 Oct 22:45:38 | 3 / `gleif:391200JI69LS8L648F30` | re-check by tier | `submitEvidence` | [`0x262662…f5cc`](https://sepolia.basescan.org/tx/0x26266251f998b4799dd82e5e93555fa07d0dcda25d0406ae3473d002b285f5cc) | [`0x9deec7…99b8`](https://sepolia.etherscan.io/tx/0x9deec79e9eb885c5c462681a00b516883d722be910696a14ff31729f6bf699b8) | clean |
| 625 | 30 Oct 23:45:14 | 0 / `ch:03778796` | re-check by tier | `submitEvidence` | [`0x0c8122…e247`](https://sepolia.basescan.org/tx/0x0c812266b6fba7442dc2f9bb1336e66fd3ade8ccb437e9c857d5400bd38fe247) | [`0x6e8f2c…f987`](https://sepolia.etherscan.io/tx/0x6e8f2c3501dd74fac4ce4d22735a0fcba534aebe142c31e63c8215335c13f987) | clean |
| 626 | 30 Oct 23:45:50 | 3 / `gleif:391200JI69LS8L648F30` | re-check by tier | `submitEvidence` | [`0x5edd1c…789a`](https://sepolia.basescan.org/tx/0x5edd1c4490609106c3257d693e6358ccc23dda7733b77a04fb4956355e08789a) | [`0x3e7323…03ef`](https://sepolia.etherscan.io/tx/0x3e7323cebb34d5ea6b1e87d98174aa8001800a55e22a02d299aa3e0b659f03ef) | clean |
| 731 | 31 Oct 00:45:50 | 0 / `ch:03778796` | re-check by tier | `submitEvidence` | [`0x592edb…d463`](https://sepolia.basescan.org/tx/0x592edb7257282721134853973eff370eea585679d18e5635400e8a2f1dc3d463) | [`0xaa257b…2360`](https://sepolia.etherscan.io/tx/0xaa257b8609c3ee70d3acbe7c85dbdf16f22ddc89bb110348fa4f974c6e962360) | clean |
| 732 | 31 Oct 00:46:39 | 3 / `gleif:391200JI69LS8L648F30` | re-check by tier | `submitEvidence` | [`0x633073…45e2`](https://sepolia.basescan.org/tx/0x63307382ae89354e66c11e5eb69c5f9eb094f07b0fba50324da6e073b40b45e2) | [`0x7d545d…c209`](https://sepolia.etherscan.io/tx/0x7d545d8ba62bad8d1226d07c9fc7d820d91aea0948edbb3dc614ca090b1dc209) | clean |
| 847 | 31 Oct 01:46:15 | 0 / `ch:03778796` | re-check by tier | `submitEvidence` | [`0xef92bb…1547`](https://sepolia.basescan.org/tx/0xef92bb14165158e9463afe5dc380b8008264bbd707f1f92d2291b27f77031547) | [`0x8c5f19…ca36`](https://sepolia.etherscan.io/tx/0x8c5f198e76879471625439afd458b209e33c6ee4517d95f2fde6a6fd13f8ca36) | clean |
| 848 | 31 Oct 01:47:03 | 3 / `gleif:391200JI69LS8L648F30` | re-check by tier | `submitEvidence` | [`0xee1ea7…e6d9`](https://sepolia.basescan.org/tx/0xee1ea709afda913068100b511cec2028f1e6d8160438faaca1e2db763c9ae6d9) | [`0x984d24…c691`](https://sepolia.etherscan.io/tx/0x984d2459bb16fcc17d5561377c80a25aba90bc2b0df6bf2340d0d7205c5bc691) | clean |
| 908 | 31 Oct 03:16:04 | 0 / `ch:03778796` | re-check by tier | `submitEvidence` | [`0x7b1f5b…7c9e`](https://sepolia.basescan.org/tx/0x7b1f5b979f88c2d4edb0f145052840a2965188b6f63875d8189a521dd3507c9e) | [`0xac62dd…1a49`](https://sepolia.etherscan.io/tx/0xac62dda1b35df44b495b48fe5d55ec8cc8075a766fbffbe4ddd4f64975a41a49) | clean |
| 908 | 31 Oct 03:32:29 | 3 / `gleif:391200JI69LS8L648F30` | re-check by tier | `submitEvidence` | [`0x9d4cc7…ed67`](https://sepolia.basescan.org/tx/0x9d4cc72855c929f62173fbab431b6ea2f8fde983d450e24e07a9247d1e10ed67) | [`0x5a9f63…0ba8`](https://sepolia.etherscan.io/tx/0x5a9f6307e9c4b66321f4e197bd9444e1f0186a1074a85e9fd49704ab3a1e0ba8) | clean |
| 909 | 31 Oct 05:08:55 | 0 / `ch:03778796` | re-check by tier | `submitEvidence` | [`0x4f8fa2…e9c1`](https://sepolia.basescan.org/tx/0x4f8fa27aa0ce2659cf37181f1b0d450b3920c15ee3db33ff746c423f9530e9c1) | [`0xaa3fc7…9f05`](https://sepolia.etherscan.io/tx/0xaa3fc7d042e38bee8c12292fc06fe39622cbf4efefa1a810e1395ab1e5d49f05) | clean |
| 909 | 31 Oct 05:19:13 | 3 / `gleif:391200JI69LS8L648F30` | re-check by tier | `submitEvidence` | [`0xfab79c…c0d8`](https://sepolia.basescan.org/tx/0xfab79cc40d557fdacf8491c28aef53a48160d4cb776c48bbe42a95e2268bc0d8) | [`0xc9e9d2…d770`](https://sepolia.etherscan.io/tx/0xc9e9d2412d4bce0ab59c92e4a056009e1640bd0e8809a20429acd7b0bbadd770) | clean |
| 911 | 31 Oct 09:27:51 | 0 / `ch:03778796` | re-check by tier | `submitEvidence` | [`0x622e26…32a2`](https://sepolia.basescan.org/tx/0x622e26c782af5a07258c76956e30ec164168e9599ece28b03d63399ecadd32a2) | [`0xd5f032…c4f0`](https://sepolia.etherscan.io/tx/0xd5f0325acc54d2fcdcc6cdbdcdff71f6e989583051b8431b501988a48a00c4f0) | clean |
| 911 | 31 Oct 09:28:03 | 3 / `gleif:391200JI69LS8L648F30` | re-check by tier | `submitEvidence` | [`0x29beda…7c72`](https://sepolia.basescan.org/tx/0x29beda164d868b5a722701f993048a0b9d3593c356d4ab5bf634b41157387c72) | [`0xfc554a…31de`](https://sepolia.etherscan.io/tx/0xfc554a53158eb462acc8bf7c64ef7335f30042a2962e1a691e053ab9949b31de) | clean |
| 1027 | 31 Oct 10:27:50 | 0 / `ch:03778796` | re-check by tier | `submitEvidence` | [`0xca6b4f…5205`](https://sepolia.basescan.org/tx/0xca6b4f3f848e846f1cebffbd1c7bd71b92e88050916c328c7d2b938a4eb75205) | [`0x139014…ef3b`](https://sepolia.etherscan.io/tx/0x13901494c83c8d6431dd8dc1acf2dd3560fc43cf8bd792b8b0461d2afaf2ef3b) | clean |
| 1029 | 31 Oct 10:32:02 | 3 / `gleif:391200JI69LS8L648F30` | re-check by tier | `submitEvidence` | [`0x164b68…008f`](https://sepolia.basescan.org/tx/0x164b68dfac90434204bb6519b39bc30453a3bbd4f49f6b5badbcdc5aaa62008f) | [`0x686d67…61d8`](https://sepolia.etherscan.io/tx/0x686d67801dd9910a7a3678e7fde7ee865c2d7a999dab751e6a12657ae56e61d8) | clean |
| 1138 | 31 Oct 11:28:27 | 0 / `ch:03778796` | re-check by tier | `submitEvidence` | [`0xa9ba70…8fd4`](https://sepolia.basescan.org/tx/0xa9ba7013d85b28909054e68b6a0dba696d20f949b07a51911dcc9362b9a38fd4) | [`0x88e783…527a`](https://sepolia.etherscan.io/tx/0x88e7836ec37fc5a9bf8bac4c682737d339bd17194db0bf6b7d22fe8c8e54527a) | clean |
| 1145 | 31 Oct 11:32:15 | 3 / `gleif:391200JI69LS8L648F30` | re-check by tier | `submitEvidence` | [`0x1b4467…67ef`](https://sepolia.basescan.org/tx/0x1b446766f310b2b70ca62d8037750668c04318b402d2e932c25ea817947067ef) | [`0x8bafcc…403c`](https://sepolia.etherscan.io/tx/0x8bafccd07cf3a155dc0c420d8eb7d5663fa0b72f07bf49247535de036509403c) | clean |
| 1170 | 31 Oct 11:45:14 | 0 / `ch:03778796` | milestone due | `release` | – | [`0x8cab05…0fc3`](https://sepolia.etherscan.io/tx/0x8cab05139af21b3b4fcf9489e9056d5a1c7e9afa4cdae9d9b8a4515047580fc3) | Paid |
| 1199 | 31 Oct 12:00:14 | 3 / `gleif:391200JI69LS8L648F30` | milestone due | `release` | – | [`0x25a56e…15bd`](https://sepolia.etherscan.io/tx/0x25a56e9ef8d610373801f1b1e9de75399e084a4f9d967517220de62e31de15bd) | Paid |

1201 cycles from 30 Oct 18:18 to 31 Oct 12:01 (CET): 40 transactions, $0.40 spent on paid checks, 2 alerts, 8 errors.

**Saturday 31 Oct** (tables above regenerated at 12:01):
- Milestone 2 of A paid by the agent at 11:45:14 and of D at 12:00:14, 14 s after each due date. D is fully paid; A's milestone 3 is due at 15:30.
- Not hidden: from 02:17 to 09:23 the laptop running the agent was asleep (lid closed on battery; `caffeinate` does not prevent that), so the agent ran only during the short wake-ups. No order was due in that window. Right after waking, the network was not up yet: two "payment failed" alerts at 09:23 and 09:27, paid fetches paused as designed, and the next checks at 09:27–09:28 went through.
- One submit at 10:31 was not mined within 180 s and was dropped; the next check of the same order (10:32) succeeded. The contract's replay checks make a late duplicate harmless.


Generated with `python3 api3/agent/pulse_agent.py report --markdown`.

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
