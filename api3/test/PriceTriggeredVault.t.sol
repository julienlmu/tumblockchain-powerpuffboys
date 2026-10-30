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
    bytes32 constant ETH_USD_REQUEST = keccak256(
        '["latestFeeds",[["name","ETH/USD"]],[["price","/ETH~1USD/value"],["updatedAt","/ETH~1USD/timestamp"]]]'
    );
    bytes32 constant BTC_USD_REQUEST = keccak256(
        '["latestFeeds",[["name","BTC/USD"]],[["price","/BTC~1USD/value"],["updatedAt","/BTC~1USD/timestamp"]]]'
    );
    uint256 constant MAX_AGE = 300;
    uint256 constant NOW = 1_800_000_000;

    address payable beneficiary = payable(address(0xBEEF));
    uint256 orderId;

    function setUp() public {
        vm.warp(NOW);
        vault = new PriceTriggeredVault(
            vm.addr(AIRNODE_KEY), ETH_USD_REQUEST, MAX_AGE, bytes('"price":'), 0, bytes('"updatedAt":')
        );
        vm.deal(address(this), 10 ether);
        orderId = vault.createOrder{value: 1 ether}(beneficiary, 3000e18, true); // pay if ETH < $3000
    }

    function _sign(uint256 key, bytes32 req, uint256 ts, bytes memory data) internal pure returns (bytes memory) {
        bytes32 h = AirnodeVerifier.ethSignedHash(AirnodeVerifier.digest(req, ts, data));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, h);
        return abi.encodePacked(r, s, v);
    }

    function _price(string memory p) internal pure returns (bytes memory) {
        return _price(p, NOW - 5);
    }

    // Nodary format: {"price":2443.95,"updatedAt":1792403240691} (updatedAt in ms)
    function _price(string memory p, uint256 updatedAt) internal pure returns (bytes memory) {
        return abi.encodePacked('{"price":', p, ',"updatedAt":', _str(updatedAt * 1000), "}");
    }

    function _str(uint256 v) internal pure returns (string memory) {
        if (v == 0) return "0";
        bytes memory b;
        while (v > 0) {
            b = abi.encodePacked(bytes1(uint8(48 + v % 10)), b);
            v /= 10;
        }
        return string(b);
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

    function test_rejectsFreshSignatureOverOldPrice() public {
        // signed just now, but the price itself was observed an hour ago
        uint256 priceTs = NOW - 3600;
        bytes memory data = _price("2987.41", priceTs);
        bytes memory sig = _sign(AIRNODE_KEY, ETH_USD_REQUEST, NOW, data);
        vm.expectRevert(abi.encodeWithSelector(PriceTriggeredVault.StalePrice.selector, priceTs, NOW));
        vault.submitAndExecute(orderId, ETH_USD_REQUEST, NOW, data, sig);
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
        bytes memory data = abi.encodePacked('{"price":67000,"updatedAt":', _str(NOW * 1000), "}");
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

    // A real response fetched from the Nodary Airnode on 2026-10-30, checked against the real signer.
    function test_realNodaryResponse() public {
        address nodary = 0xE70f1e8b22a21e4Bb5188918a3033341b281E4c0;
        bytes32 req = 0x180eae9387bb66a72380e61ebe0a00d19f8414a716a37ebe1df124b66acfff66;
        uint256 ts = 1793358553;
        bytes memory data = bytes('{"price":2246.485,"updatedAt":1793358553047}');
        bytes memory sig =
            hex"074296f4af24e056f6c94db2a3f5985a78eda834ab21f76437728b81ba904430185c5a9ca5b404439e491e8fad7a1b9288eec7d7829cc8ecae9c4dba2deb02b31c";

        vm.warp(ts + 10);
        PriceTriggeredVault real = new PriceTriggeredVault(nodary, req, MAX_AGE, bytes('"price":'), 0, bytes('"updatedAt":'));
        uint256 id = real.createOrder{value: 1 ether}(beneficiary, 3000e18, true);

        // one edited digit: rejected
        bytes memory edited = bytes('{"price":2246.486,"updatedAt":1793358553047}');
        address recovered = AirnodeVerifier.recover(req, ts, edited, sig);
        vm.expectRevert(abi.encodeWithSelector(PriceTriggeredVault.WrongSigner.selector, recovered));
        real.submitAndExecute(id, req, ts, edited, sig);

        // untouched: accepted, 2246.485 < 3000 so the order pays out
        real.submitAndExecute(id, req, ts, data, sig);
        assertEq(real.latestPrice(), 2246.485e18, "price");
        assertEq(beneficiary.balance, 1 ether, "paid out");
    }

    receive() external payable {}
}
