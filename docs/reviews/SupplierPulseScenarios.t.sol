// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {SupplierPulseTest} from "./SupplierPulse.t.sol";
import {SupplierPulse} from "../src/SupplierPulse.sol";

contract ReviewScenarios is SupplierPulseTest {
    function _secondOrder() internal returns (uint256) {
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1 ether;
        return pulse.createOrder{value: 1 ether}(supplier, "01234567", keccak256("PO-SECOND"), amounts, PERMIT_TTL);
    }

    function test_review_sameEvidenceCannotServeTwoOrders() public {
        uint256 second = _secondOrder();
        bytes memory data = _status("active");
        bytes memory sig = _sign(AIRNODE_KEY, MOTOR_CO, NOW, data);
        pulse.submitEvidence(orderId, MOTOR_CO, NOW, data, sig);
        vm.expectRevert(abi.encodeWithSelector(SupplierPulse.Replayed.selector, keccak256(abi.encodePacked(MOTOR_CO, NOW, data))));
        pulse.submitEvidence(second, MOTOR_CO, NOW, data, sig);
    }

    function test_review_liquidationOnSecondOrderDoesNotInvalidateFirstPermit() public {
        uint256 second = _secondOrder();
        _check("active", NOW);
        vm.warp(NOW + 10);
        bytes memory data = _status("liquidation");
        pulse.submitEvidence(second, MOTOR_CO, NOW + 10, data, _sign(AIRNODE_KEY, MOTOR_CO, NOW + 10, data));
        pulse.approveMilestone(orderId, 0);
        pulse.release(orderId);
        assertEq(supplier.balance, 0.5 ether, "first order still pays after newer negative evidence on second");
    }

    function test_review_permitCanOutliveEvidenceMaxAge() public {
        _check("active", NOW);
        vm.warp(NOW + MAX_AGE + 1);
        pulse.approveMilestone(orderId, 0);
        pulse.release(orderId);
        assertEq(supplier.balance, 0.5 ether, "permit lifetime controls release, not maxAge");
    }

    function test_review_buyerHasNoTimeoutRefundWhileOrderIsActive() public {
        vm.warp(NOW + 365 days);
        vm.expectRevert(SupplierPulse.NotHeld.selector);
        pulse.refundRemaining(orderId);
        (, , uint256 remaining, ) = _state();
        assertEq(remaining, 2 ether, "remaining balance is still locked");
    }
}
