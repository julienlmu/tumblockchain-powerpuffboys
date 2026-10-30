// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TestBase} from "./utils/Vm.sol";
import {PriceTriggeredVault} from "../src/PriceTriggeredVault.sol";
import {AirnodeVerifier} from "../src/AirnodeVerifier.sol";

/// Tamper tests: the vault must only act on an untouched, fresh, unused response
/// for the expected request, signed by the trusted Airnode.
contract PriceTriggeredVaultTest is TestBase {
    PriceTriggeredVault vault;

    uint256 constant AIRNODE_KEY = 0xA11CE;
    uint256 constant ATTACKER_KEY = 0xBAD;
    bytes32 constant ETH_USD_REQUEST = keccak256('["coinPrice",{"ids":"ethereum","vs_currencies":"usd"}]');
    bytes32 constant BTC_USD_REQUEST = keccak256('["coinPrice",{"ids":"bitcoin","vs_currencies":"usd"}]');
    uint256 constant MAX_AGE = 300;
    uint256 constant NOW = 1_800_000_000;

    address payable beneficiary = payable(address(0xBEEF));
    uint256 orderId;

    function setUp() public {
        vm.warp(NOW);
        vault = new PriceTriggeredVault(vm.addr(AIRNODE_KEY), ETH_USD_REQUEST, MAX_AGE, bytes('"usd":'), 0);
        vm.deal(address(this), 10 ether);
        orderId = vault.createOrder{value: 1 ether}(beneficiary, 3000e18, true); // pay if ETH < $3000
    }

    function _sign(uint256 key, bytes32 req, uint256 ts, bytes memory data) internal pure returns (bytes memory) {
        bytes32 h = AirnodeVerifier.ethSignedHash(AirnodeVerifier.digest(req, ts, data));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, h);
        return abi.encodePacked(r, s, v);
    }

    function _price(string memory p) internal pure returns (bytes memory) {
        return abi.encodePacked('{"ethereum":{"usd":', p, "}}");
    }

    // ------------------------------------------------------------ happy path

    function test_validResponseExecutes() public {
        bytes memory data = _price("2987.41");
        bytes memory sig = _sign(AIRNODE_KEY, ETH_USD_REQUEST, NOW - 10, data);
        vault.submitAndExecute(orderId, ETH_USD_REQUEST, NOW - 10, data, sig);
        assertEq(vault.latestPrice(), 2987.41e18, "price");
        assertEq(beneficiary.balance, 1 ether, "paid out");
    }

    function test_conditionNotMetKeepsOrderOpen() public {
        bytes memory data = _price("3100.5");
        bytes memory sig = _sign(AIRNODE_KEY, ETH_USD_REQUEST, NOW, data);
        (uint256 price, bool executed) = vault.submitAndTryExecute(orderId, ETH_USD_REQUEST, NOW, data, sig);
        assertEq(price, 3100.5e18, "price");
        assertTrue(!executed, "should not execute");
        assertEq(beneficiary.balance, 0, "no payout");

        vm.expectRevert(
            abi.encodeWithSelector(PriceTriggeredVault.ConditionNotMet.selector, 3100.5e18, 3000e18, true)
        );
        vault.execute(orderId);
    }

    // --------------------------------------------------------- tamper tests

    function test_rejectsModifiedValue() public {
        bytes memory signed = _price("3100.5");
        bytes memory sig = _sign(AIRNODE_KEY, ETH_USD_REQUEST, NOW, signed);
        bytes memory tampered = _price("2100.5"); // attacker lowers the price to trigger payout
        address recovered = AirnodeVerifier.recover(ETH_USD_REQUEST, NOW, tampered, sig);
        vm.expectRevert(abi.encodeWithSelector(PriceTriggeredVault.WrongSigner.selector, recovered));
        vault.submitAndExecute(orderId, ETH_USD_REQUEST, NOW, tampered, sig);
        assertEq(beneficiary.balance, 0, "no payout");
    }

    function test_rejectsModifiedTimestamp() public {
        bytes memory data = _price("2987.41");
        bytes memory sig = _sign(AIRNODE_KEY, ETH_USD_REQUEST, NOW - 1000, data);
        address recovered = AirnodeVerifier.recover(ETH_USD_REQUEST, NOW, data, sig);
        vm.expectRevert(abi.encodeWithSelector(PriceTriggeredVault.WrongSigner.selector, recovered));
        vault.submitPrice(ETH_USD_REQUEST, NOW, data, sig); // pretend an old response is new
    }

    function test_rejectsStaleResponse() public {
        uint256 ts = NOW - MAX_AGE - 1;
        bytes memory data = _price("2987.41");
        bytes memory sig = _sign(AIRNODE_KEY, ETH_USD_REQUEST, ts, data);
        vm.expectRevert(abi.encodeWithSelector(PriceTriggeredVault.StaleResponse.selector, ts, NOW));
        vault.submitAndExecute(orderId, ETH_USD_REQUEST, ts, data, sig);
    }

    function test_rejectsFutureResponse() public {
        uint256 ts = NOW + 3600;
        bytes memory data = _price("2987.41");
        bytes memory sig = _sign(AIRNODE_KEY, ETH_USD_REQUEST, ts, data);
        vm.expectRevert(abi.encodeWithSelector(PriceTriggeredVault.FutureResponse.selector, ts, NOW));
        vault.submitPrice(ETH_USD_REQUEST, ts, data, sig);
    }

    function test_rejectsOtherRequest() public {
        // validly signed by the trusted Airnode, but for BTC/USD, not ETH/USD
        bytes memory data = abi.encodePacked('{"bitcoin":{"usd":67000}}');
        bytes memory sig = _sign(AIRNODE_KEY, BTC_USD_REQUEST, NOW, data);
        vm.expectRevert(abi.encodeWithSelector(PriceTriggeredVault.WrongRequest.selector, BTC_USD_REQUEST));
        vault.submitAndExecute(orderId, BTC_USD_REQUEST, NOW, data, sig);
    }

    function test_rejectsOtherRequestHashSwap() public {
        // signature for BTC request, attacker relabels it as the ETH request
        bytes memory data = _price("10");
        bytes memory sig = _sign(AIRNODE_KEY, BTC_USD_REQUEST, NOW, data);
        address recovered = AirnodeVerifier.recover(ETH_USD_REQUEST, NOW, data, sig);
        vm.expectRevert(abi.encodeWithSelector(PriceTriggeredVault.WrongSigner.selector, recovered));
        vault.submitAndExecute(orderId, ETH_USD_REQUEST, NOW, data, sig);
    }

    function test_rejectsWrongKey() public {
        bytes memory data = _price("2987.41");
        bytes memory sig = _sign(ATTACKER_KEY, ETH_USD_REQUEST, NOW, data);
        vm.expectRevert(abi.encodeWithSelector(PriceTriggeredVault.WrongSigner.selector, vm.addr(ATTACKER_KEY)));
        vault.submitAndExecute(orderId, ETH_USD_REQUEST, NOW, data, sig);
    }

    function test_rejectsReplay() public {
        bytes memory data = _price("3100.5");
        bytes memory sig = _sign(AIRNODE_KEY, ETH_USD_REQUEST, NOW, data);
        vault.submitPrice(ETH_USD_REQUEST, NOW, data, sig);
        bytes32 d = AirnodeVerifier.digest(ETH_USD_REQUEST, NOW, data);
        vm.expectRevert(abi.encodeWithSelector(PriceTriggeredVault.Replayed.selector, d));
        vault.submitPrice(ETH_USD_REQUEST, NOW, data, sig);
    }

    function test_rejectsOlderThanLatest() public {
        // an old but still fresh low price cannot override a newer high one
        bytes memory oldData = _price("2500");
        bytes memory oldSig = _sign(AIRNODE_KEY, ETH_USD_REQUEST, NOW - 60, oldData);
        bytes memory newData = _price("3100");
        vault.submitPrice(ETH_USD_REQUEST, NOW, newData, _sign(AIRNODE_KEY, ETH_USD_REQUEST, NOW, newData));
        vm.expectRevert(abi.encodeWithSelector(PriceTriggeredVault.NotNewer.selector, NOW - 60, NOW));
        vault.submitAndExecute(orderId, ETH_USD_REQUEST, NOW - 60, oldData, oldSig);
    }

    function test_rejectsMalleableSignature() public {
        bytes memory data = _price("2987.41");
        bytes memory sig = _sign(AIRNODE_KEY, ETH_USD_REQUEST, NOW, data);
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := mload(add(sig, 0x20))
            s := mload(add(sig, 0x40))
            v := byte(0, mload(add(sig, 0x60)))
        }
        uint256 n = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141;
        bytes memory flipped = abi.encodePacked(r, bytes32(n - uint256(s)), v == 27 ? uint8(28) : uint8(27));
        vm.expectRevert(AirnodeVerifier.InvalidSignatureS.selector);
        vault.submitPrice(ETH_USD_REQUEST, NOW, data, flipped);
    }

    function test_executeNeedsFreshPrice() public {
        bytes memory data = _price("2987.41");
        vault.submitPrice(ETH_USD_REQUEST, NOW, data, _sign(AIRNODE_KEY, ETH_USD_REQUEST, NOW, data));
        vm.warp(NOW + MAX_AGE + 1);
        vm.expectRevert(PriceTriggeredVault.NoFreshPrice.selector);
        vault.execute(orderId);
    }

    function test_cannotExecuteTwice() public {
        bytes memory data = _price("2987.41");
        vault.submitAndExecute(orderId, ETH_USD_REQUEST, NOW, data, _sign(AIRNODE_KEY, ETH_USD_REQUEST, NOW, data));
        vm.expectRevert(PriceTriggeredVault.BadOrder.selector);
        vault.execute(orderId);
    }

    function test_onlyOwnerCancels() public {
        vm.prank(address(0xCAFE));
        vm.expectRevert(PriceTriggeredVault.NotAuthorized.selector);
        vault.cancel(orderId);
        uint256 before = address(this).balance;
        vault.cancel(orderId);
        assertEq(address(this).balance, before + 1 ether, "refund");
    }

    receive() external payable {}
}
