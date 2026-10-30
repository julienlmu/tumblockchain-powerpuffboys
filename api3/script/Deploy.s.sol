// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Vm} from "../test/utils/Vm.sol";
import {PriceTriggeredVault} from "../src/PriceTriggeredVault.sol";

/// forge script script/Deploy.s.sol --rpc-url $EVM_RPC_URL --broadcast
/// env: EVM_PRIVATE_KEY, AIRNODE_ADDRESS, REQUEST_HASH, [MAX_AGE=300], [PRICE_KEY='"usd":'], [SOURCE_DECIMALS=0]
contract Deploy {
    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function run() external returns (PriceTriggeredVault vault) {
        uint256 key = vm.envUint("EVM_PRIVATE_KEY");
        address airnode = vm.envAddress("AIRNODE_ADDRESS");
        bytes32 requestHash = vm.envBytes32("REQUEST_HASH");
        uint256 maxAge = vm.envOr("MAX_AGE", uint256(300));
        string memory priceKey = vm.envOr("PRICE_KEY", string('"usd":'));
        uint256 sourceDecimals = vm.envOr("SOURCE_DECIMALS", uint256(0));

        vm.startBroadcast(key);
        vault = new PriceTriggeredVault(airnode, requestHash, maxAge, bytes(priceKey), uint8(sourceDecimals));
        vm.stopBroadcast();
    }
}
