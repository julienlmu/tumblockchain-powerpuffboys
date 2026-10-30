// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TestBase} from "./utils/Vm.sol";
import {SupplierPulse} from "../src/SupplierPulse.sol";
import {AirnodeVerifier} from "../src/AirnodeVerifier.sol";

/// Milestone payments that need fresh signed registry evidence, plus the tamper tests.
contract SupplierPulseTest is TestBase {
    SupplierPulse pulse;

    uint256 constant AIRNODE_KEY = 0xA11CE;
    uint256 constant ATTACKER_KEY = 0xBAD;
    bytes32 constant MOTOR_CO = keccak256('["getCompanyProfile",[["companyNumber","01234567"]],[["status","/company_status"]]]');
    bytes32 constant OTHER_CO = keccak256('["getCompanyProfile",[["companyNumber","07654321"]],[["status","/company_status"]]]');
    uint256 constant MAX_AGE = 300;
    uint64 constant PERMIT_TTL = 1 days;
    uint256 constant NOW = 1_800_000_000;

    address buyer = address(this);
    address payable supplier = payable(address(0xBEEF));
    uint256 orderId;

    receive() external payable {}

    function setUp() public {
        vm.warp(NOW);
        pulse = new SupplierPulse(vm.addr(AIRNODE_KEY), MAX_AGE, bytes('"status":'));
        vm.deal(address(this), 10 ether);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 0.5 ether;
        amounts[1] = 1.5 ether;
        orderId = pulse.createOrder{value: 2 ether}(supplier, MOTOR_CO, keccak256("PO-1042"), amounts, PERMIT_TTL);
    }

    function _sign(uint256 key, bytes32 req, uint256 ts, bytes memory data) internal pure returns (bytes memory) {
        bytes32 h = AirnodeVerifier.ethSignedHash(AirnodeVerifier.digest(req, ts, data));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, h);
        return abi.encodePacked(r, s, v);
    }

    function _status(string memory s) internal pure returns (bytes memory) {
        return abi.encodePacked('{"status":"', s, '"}');
    }

    function _check(string memory s, uint256 ts) internal returns (SupplierPulse.Outcome) {
        bytes memory data = _status(s);
        return pulse.checkAndRelease(orderId, MOTOR_CO, ts, data, _sign(AIRNODE_KEY, MOTOR_CO, ts, data));
    }

    function _state() internal view returns (SupplierPulse.State state, uint256 paid, uint256 remaining, bool permitValid) {
        (state, paid, remaining,,,, permitValid,,) = pulse.orderStatus(orderId);
    }

    // ------------------------------------------------------------ scenarios

    function test_paysBothMilestonesWithFreshEvidence() public {
        pulse.approveMilestone(orderId, 0);
        assertTrue(_check("active", NOW) == SupplierPulse.Outcome.Paid, "first paid");
        assertEq(supplier.balance, 0.5 ether, "advance");

        vm.warp(NOW + 30 days);
        pulse.approveMilestone(orderId, 1);
        assertTrue(_check("active", NOW + 30 days - 5) == SupplierPulse.Outcome.Paid, "second paid");
        assertEq(supplier.balance, 2 ether, "all paid");

        (SupplierPulse.State state, uint256 paid, uint256 remaining,) = _state();
        assertTrue(state == SupplierPulse.State.Closed, "closed");
        assertEq(paid, 2 ether, "paid");
        assertEq(remaining, 0, "remaining");
    }

    function test_holdsRemainderWhenStatusChanges() public {
        pulse.approveMilestone(orderId, 0);
        _check("active", NOW);

        vm.warp(NOW + 30 days);
        pulse.approveMilestone(orderId, 1);
        assertTrue(_check("liquidation", NOW + 30 days) == SupplierPulse.Outcome.Held, "held");
        assertEq(supplier.balance, 0.5 ether, "second payment stopped");

        (SupplierPulse.State state,, uint256 remaining, bool permitValid) = _state();
        assertTrue(state == SupplierPulse.State.Held, "state held");
        assertEq(remaining, 1.5 ether, "protected remaining balance");
        assertTrue(!permitValid, "no permit");

        vm.expectRevert(abi.encodeWithSelector(SupplierPulse.NotActive.selector, SupplierPulse.State.Held));
        pulse.release(orderId);

        uint256 before = address(this).balance;
        pulse.refundRemaining(orderId);
        assertEq(address(this).balance - before, 1.5 ether, "buyer refunded");
    }

    function test_waitsForBuyerApproval() public {
        assertTrue(_check("active", NOW) == SupplierPulse.Outcome.AwaitingApproval, "awaiting");
        assertEq(supplier.balance, 0, "not paid");
        pulse.approveMilestone(orderId, 0);
        pulse.release(orderId); // the permit is still valid
        assertEq(supplier.balance, 0.5 ether, "paid after approval");
    }

    function test_expiredPermitNeedsNewEvidence() public {
        _check("active", NOW);
        vm.warp(NOW + PERMIT_TTL + 1);
        pulse.approveMilestone(orderId, 0);
        vm.expectRevert(abi.encodeWithSelector(SupplierPulse.PermitExpired.selector, NOW + PERMIT_TTL, NOW + PERMIT_TTL + 1));
        pulse.release(orderId);

        _check("active", NOW + PERMIT_TTL + 1);
        assertEq(supplier.balance, 0.5 ether, "paid with new evidence");
    }

    function test_permitIsUsedUpByPayment() public {
        pulse.approveMilestone(orderId, 0);
        pulse.approveMilestone(orderId, 1);
        _check("active", NOW); // pays milestone 0
        vm.expectRevert(abi.encodeWithSelector(SupplierPulse.NoValidPermit.selector, 1));
        pulse.release(orderId); // milestone 1 needs its own evidence
        assertEq(supplier.balance, 0.5 ether, "only one stage paid");
    }

    function test_onlyBuyerApprovesAndRefunds() public {
        vm.prank(supplier);
        vm.expectRevert(SupplierPulse.NotAuthorized.selector);
        pulse.approveMilestone(orderId, 0);

        vm.expectRevert(SupplierPulse.NotHeld.selector);
        pulse.refundRemaining(orderId);
    }

    function test_orderMustBeFullyFunded() public {
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1 ether;
        vm.expectRevert(SupplierPulse.BadOrder.selector);
        pulse.createOrder{value: 0.9 ether}(supplier, MOTOR_CO, bytes32(0), amounts, PERMIT_TTL);
    }

    // --------------------------------------------------------- tamper tests

    function test_rejectsEditedStatus() public {
        bytes memory signed = _status("dissolved");
        bytes memory sig = _sign(AIRNODE_KEY, MOTOR_CO, NOW, signed);
        bytes memory tampered = _status("active"); // attacker flips the status to get paid
        address recovered = AirnodeVerifier.recover(MOTOR_CO, NOW, tampered, sig);
        vm.expectRevert(abi.encodeWithSelector(SupplierPulse.WrongSigner.selector, recovered));
        pulse.checkAndRelease(orderId, MOTOR_CO, NOW, tampered, sig);
    }

    function test_rejectsStaleResponse() public {
        uint256 ts = NOW - MAX_AGE - 1;
        bytes memory data = _status("active");
        bytes memory sig = _sign(AIRNODE_KEY, MOTOR_CO, ts, data);
        vm.expectRevert(abi.encodeWithSelector(SupplierPulse.StaleResponse.selector, ts, NOW));
        pulse.checkAndRelease(orderId, MOTOR_CO, ts, data, sig);
    }

    function test_rejectsOtherCompany() public {
        bytes memory data = _status("active"); // genuinely signed, but for another company
        bytes memory sig = _sign(AIRNODE_KEY, OTHER_CO, NOW, data);
        vm.expectRevert(abi.encodeWithSelector(SupplierPulse.WrongRequest.selector, OTHER_CO, MOTOR_CO));
        pulse.checkAndRelease(orderId, OTHER_CO, NOW, data, sig);
    }

    function test_rejectsWrongKey() public {
        bytes memory data = _status("active");
        bytes memory sig = _sign(ATTACKER_KEY, MOTOR_CO, NOW, data);
        vm.expectRevert(abi.encodeWithSelector(SupplierPulse.WrongSigner.selector, vm.addr(ATTACKER_KEY)));
        pulse.checkAndRelease(orderId, MOTOR_CO, NOW, data, sig);
    }

    function test_rejectsReplay() public {
        bytes memory data = _status("active");
        bytes memory sig = _sign(AIRNODE_KEY, MOTOR_CO, NOW, data);
        pulse.checkAndRelease(orderId, MOTOR_CO, NOW, data, sig);
        bytes32 d = AirnodeVerifier.digest(MOTOR_CO, NOW, data);
        vm.expectRevert(abi.encodeWithSelector(SupplierPulse.Replayed.selector, d));
        pulse.checkAndRelease(orderId, MOTOR_CO, NOW, data, sig);
    }

    function test_rejectsOlderEvidenceAfterNewer() public {
        _check("active", NOW);
        bytes memory data = _status("active");
        bytes memory sig = _sign(AIRNODE_KEY, MOTOR_CO, NOW - 10, data);
        vm.expectRevert(abi.encodeWithSelector(SupplierPulse.NotNewer.selector, NOW - 10, NOW));
        pulse.checkAndRelease(orderId, MOTOR_CO, NOW - 10, data, sig);
    }

    function test_rejectsFutureTimestamp() public {
        uint256 ts = NOW + 61;
        bytes memory data = _status("active");
        bytes memory sig = _sign(AIRNODE_KEY, MOTOR_CO, ts, data);
        vm.expectRevert(abi.encodeWithSelector(SupplierPulse.FutureResponse.selector, ts, NOW));
        pulse.checkAndRelease(orderId, MOTOR_CO, ts, data, sig);
    }
}
