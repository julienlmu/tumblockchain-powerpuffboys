// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Vm} from "../test/utils/Vm.sol";
import {PriceTriggeredVault} from "../src/PriceTriggeredVault.sol";

/// forge script script/Deploy.s.sol --rpc-url $EVM_RPC_URL --broadcast
/// env: EVM_PRIVATE_KEY, [AIRNODE_ADDRESS=Nodary], [REQUEST_HASH=Nodary ETH/USD], [MAX_AGE=300],
///      [PRICE_KEY='"price":'], [SOURCE_DECIMALS=0], [UPDATED_AT_KEY='"updatedAt":']
contract Deploy {
    // Nodary Airnode v2 signer (x-airnode of https://airnode-nodary.fly.dev/)
    address constant NODARY_AIRNODE = 0xE70f1e8b22a21e4Bb5188918a3033341b281E4c0;

    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    // request hash preimage of the POST in scripts/fetch-eth-usd.sh
    string constant NODARY_ETH_USD =
        '["latestFeeds",[["name","ETH/USD"]],[["price","/ETH~1USD/value"],["updatedAt","/ETH~1USD/timestamp"]]]';

    function run() external returns (PriceTriggeredVault vault) {
        uint256 key = vm.envUint("EVM_PRIVATE_KEY");
        address airnode = vm.envOr("AIRNODE_ADDRESS", NODARY_AIRNODE);
        bytes32 requestHash = vm.envOr("REQUEST_HASH", keccak256(bytes(NODARY_ETH_USD)));
        uint256 maxAge = vm.envOr("MAX_AGE", uint256(300));
        string memory priceKey = vm.envOr("PRICE_KEY", string('"price":'));
        uint256 sourceDecimals = vm.envOr("SOURCE_DECIMALS", uint256(0));
        string memory updatedAtKey = vm.envOr("UPDATED_AT_KEY", string('"updatedAt":'));

        vm.startBroadcast(key);
        vault = new PriceTriggeredVault(airnode, requestHash, maxAge, bytes(priceKey), uint8(sourceDecimals), bytes(updatedAtKey));
        vm.stopBroadcast();
    }
}
