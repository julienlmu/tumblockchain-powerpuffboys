// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Vm} from "../test/utils/Vm.sol";
import {SupplierPulse} from "../src/SupplierPulse.sol";

/// forge script script/DeploySupplierPulse.s.sol --rpc-url $EVM_RPC_URL --broadcast --slow
/// env: EVM_PRIVATE_KEY, [PULSE_AIRNODE=Companies House Airnode], [MAX_AGE=300]
contract DeploySupplierPulse {
    // Companies House Airnode signer (https://airnode-companies-house.fly.dev/)
    address constant COMPANIES_HOUSE_AIRNODE = 0x392228E5CCA260313e5ed337Ed3561B59A1e4bFF;

    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function run() external returns (SupplierPulse pulse) {
        uint256 key = vm.envUint("EVM_PRIVATE_KEY");
        address airnode = vm.envOr("PULSE_AIRNODE", COMPANIES_HOUSE_AIRNODE);
        uint256 maxAge = vm.envOr("MAX_AGE", uint256(300));

        vm.startBroadcast(key);
        pulse = new SupplierPulse(airnode, maxAge, bytes('"status":'));
        vm.stopBroadcast();
    }
}
