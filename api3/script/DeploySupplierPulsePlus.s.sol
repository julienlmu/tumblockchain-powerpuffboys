// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Vm} from "../test/utils/Vm.sol";
import {SupplierPulsePlus} from "../src/SupplierPulsePlus.sol";

/// forge script script/DeploySupplierPulsePlus.s.sol --rpc-url $EVM_RPC_URL --broadcast --slow --gas-estimate-multiplier 800
/// env: EVM_PRIVATE_KEY, [CH_AIRNODE] [GLEIF_AIRNODE] (default: the real signers),
///      [MAX_AGE=300] [TIER_COUNT_GAP=300] [REFUND_GRACE=600] (defaults: the Sepolia demo values)
contract DeploySupplierPulsePlus {
    // https://airnode-companies-house.fly.dev/
    address constant COMPANIES_HOUSE_AIRNODE = 0x392228E5CCA260313e5ed337Ed3561B59A1e4bFF;
    // https://airnode-gleif.fly.dev/
    address constant GLEIF_AIRNODE = 0x26d83124541e89ef28B9A5FB012B4B5f4097C20c;

    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function run() external returns (SupplierPulsePlus pulse) {
        uint256 key = vm.envUint("EVM_PRIVATE_KEY");
        address ch = vm.envOr("CH_AIRNODE", COMPANIES_HOUSE_AIRNODE);
        address gleif = vm.envOr("GLEIF_AIRNODE", GLEIF_AIRNODE);
        uint256 maxAge = vm.envOr("MAX_AGE", uint256(300));
        uint64 gap = uint64(vm.envOr("TIER_COUNT_GAP", uint256(300)));
        uint64 grace = uint64(vm.envOr("REFUND_GRACE", uint256(600)));

        vm.startBroadcast(key);
        pulse = new SupplierPulsePlus(ch, gleif, maxAge, gap, grace);
        vm.stopBroadcast();
    }
}
