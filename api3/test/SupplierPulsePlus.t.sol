// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TestBase} from "./utils/Vm.sol";
import {ISupplierPulsePlus} from "../src/ISupplierPulsePlus.sol";
import {SupplierPulsePlus} from "../src/SupplierPulsePlus.sol";
import {AirnodeVerifier} from "../src/AirnodeVerifier.sol";
import {JsonFields} from "../src/JsonFields.sol";

/// Cheatcodes used here on top of the shared minimal Vm.
interface VmEvents {
    function expectEmit(bool checkTopic1, bool checkTopic2, bool checkTopic3, bool checkData, address emitter)
        external;
}

/// Exposes the internal JsonFields library for direct tests.
contract JsonFieldsHarness {
    function parseBool(bytes calldata data, bytes calldata key) external pure returns (bool) {
        return JsonFields.parseBool(data, key);
    }
}

/// SupplierPulse+ (docs/SUPPLIERPULSE_PLUS.md §4.4, §4.5): two registries, buyer rules, trust tiers,
/// due dates, refund grace, and every tamper case.
contract SupplierPulsePlusTest is TestBase {
    VmEvents constant vmE = VmEvents(address(uint160(uint256(keccak256("hevm cheat code")))));

    SupplierPulsePlus pulse;

    uint256 constant CH_KEY = 0xA11CE;
    uint256 constant GLEIF_KEY = 0x61E1F;
    uint256 constant ATTACKER_KEY = 0xBAD;
    uint256 constant MAX_AGE = 300;
    uint64 constant GAP = 60;
    uint64 constant GRACE = 120;
    uint64 constant TTL = 1000;
    uint256 constant NOW = 1_800_000_000;
    uint256 constant N = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141;

    string constant CH_ID = "09729896";
    string constant LEI = "TESTLEI0000000000000";
    bytes32 constant CH_REQ = 0x6e84889a218993dcdaaa5e41a15b5b1bba283e48ca36763248620abbe2f17f0f;
    bytes32 constant LEI_REQ = 0x82e8da1da50a59eb4941e8461f35869cb1a4a95183dc1ea84075b99af97d790f;

    address payable supplier = payable(address(0xBEEF));
    address stranger = address(0xCAFE);

    receive() external payable {}

    function setUp() public {
        vm.warp(NOW);
        pulse = new SupplierPulsePlus(vm.addr(CH_KEY), vm.addr(GLEIF_KEY), MAX_AGE, GAP, GRACE);
        vm.deal(address(this), 100 ether);
    }

    // -------------------------------------------------------------- helpers

    function _amounts(uint256 n) internal pure returns (uint256[] memory a) {
        a = new uint256[](n);
        for (uint256 i = 0; i < n; i++) {
            a[i] = (i + 1) * 1 ether;
        }
    }

    function _dues(uint256 n, uint256 first, uint256 step) internal pure returns (uint64[] memory d) {
        d = new uint64[](n);
        for (uint256 i = 0; i < n; i++) {
            d[i] = uint64(first + i * step);
        }
    }

    function _total(uint256 n) internal pure returns (uint256) {
        return n * (n + 1) / 2 * 1 ether;
    }

    /// n milestones of 1, 2, 3… ether, all due now
    function _order(uint8 source, string memory id, uint256 n, uint8 rules) internal returns (uint256) {
        return pulse.createOrder{value: _total(n)}(
            source, id, supplier, keccak256("PO-1001"), _amounts(n), _dues(n, NOW, 0), TTL, rules
        );
    }

    function _ch(bool accounts, bool confirmation, string memory status) internal pure returns (bytes memory) {
        return abi.encodePacked(
            '{"accounts_overdue":',
            accounts ? "true" : "false",
            ',"confirmation_overdue":',
            confirmation ? "true" : "false",
            ',"status":"',
            status,
            '"}'
        );
    }

    function _chClean() internal pure returns (bytes memory) {
        return _ch(false, false, "active");
    }

    function _gleif(string memory entity, string memory reg) internal pure returns (bytes memory) {
        return abi.encodePacked('{"entity_status":"', entity, '","registration_status":"', reg, '"}');
    }

    function _sign(uint256 key, bytes32 req, uint256 ts, bytes memory data) internal pure returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, AirnodeVerifier.ethSignedHash(AirnodeVerifier.digest(req, ts, data)));
        return abi.encodePacked(r, s, v);
    }

    function _keyOf(uint256 orderId) internal view returns (uint256 key, bytes32 req) {
        (,, uint8 source,, bytes32 r,,,) = pulse.orderInfo(orderId);
        return (source == 0 ? CH_KEY : GLEIF_KEY, r);
    }

    function _submit(uint256 orderId, bytes memory data, uint256 ts) internal returns (bool) {
        (uint256 key, bytes32 req) = _keyOf(orderId);
        return pulse.submitEvidence(orderId, req, ts, data, _sign(key, req, ts, data));
    }

    function _check(uint256 orderId, bytes memory data, uint256 ts) internal returns (uint8) {
        (uint256 key, bytes32 req) = _keyOf(orderId);
        return pulse.checkAndRelease(orderId, req, ts, data, _sign(key, req, ts, data));
    }

    function _failed(uint256 orderId) internal view returns (uint8 f) {
        (,, f,,,) = pulse.orderSchedule(orderId);
    }

    function _state(uint256 orderId) internal view returns (uint8 s) {
        (s,,,,,,,) = pulse.orderStatus(orderId);
    }

    function _tier(bytes32 key) internal view returns (uint8 t) {
        (,,,,,, t) = pulse.supplierRecord(key);
    }

    function _streak(bytes32 key) internal view returns (uint32 s) {
        (s,,,,,,) = pulse.supplierRecord(key);
    }

    function _failedAt(bytes32 key) internal view returns (uint64 f) {
        (,,,,, f,) = pulse.supplierRecord(key);
    }

    function _expectRevert(bytes memory err) internal {
        vm.expectRevert(err);
    }

    // ------------------------------------------------------ hashes and keys

    function test_requestHashVectors() public view {
        assertTrue(pulse.requestHashFor(0, CH_ID) == CH_REQ, "CH vector");
        assertTrue(pulse.requestHashFor(1, LEI) == LEI_REQ, "GLEIF vector");
    }

    function test_supplierKeyVectors() public view {
        assertTrue(
            pulse.supplierKeyOf(0, CH_ID) == 0xabf8d9a610a62d829c8b4ecdf8bee9db7988e3386692f4e1667c46a4698b3d2a, "CH key"
        );
        assertTrue(
            pulse.supplierKeyOf(1, LEI) == 0x31b072a73946faf810268129043fd17faebcf51b0756ab720dffc03eaaefe0f6, "LEI key"
        );
    }

    function test_constructorConfig() public view {
        assertTrue(pulse.airnodeOf(0) == vm.addr(CH_KEY), "ch airnode");
        assertTrue(pulse.airnodeOf(1) == vm.addr(GLEIF_KEY), "gleif airnode");
        assertEq(pulse.maxAge(), MAX_AGE, "maxAge");
        assertEq(pulse.tierCountGap(), GAP, "gap");
        assertEq(pulse.refundGrace(), GRACE, "grace");
        assertTrue(pulse.admin() == address(this), "admin");
    }

    // ------------------------------------------------------------ bad input

    function test_badSupplierId() public {
        string[5] memory bad = ["", "12345678901", "ab123456", "0972-896", "TESTLEI000000000000"];
        uint8[5] memory src = [0, 0, 0, 0, 1];
        for (uint256 i = 0; i < bad.length; i++) {
            vm.expectRevert(ISupplierPulsePlus.BadSupplierId.selector);
            pulse.createOrder{value: 1 ether}(src[i], bad[i], supplier, 0, _amounts(1), _dues(1, NOW, 0), TTL, 0);
        }
        vm.expectRevert(ISupplierPulsePlus.BadSupplierId.selector);
        pulse.requestHashFor(1, "TESTLEI00000000000000"); // 21 characters
        assertTrue(pulse.requestHashFor(0, "SC193794") != bytes32(0), "letter prefix ok");
    }

    function test_badRules() public {
        vm.expectRevert(ISupplierPulsePlus.BadRules.selector);
        pulse.createOrder{value: 1 ether}(0, CH_ID, supplier, 0, _amounts(1), _dues(1, NOW, 0), TTL, 0x08);
        vm.expectRevert(ISupplierPulsePlus.BadRules.selector); // 0x01 is reserved since v1.1
        pulse.createOrder{value: 1 ether}(0, CH_ID, supplier, 0, _amounts(1), _dues(1, NOW, 0), TTL, 0x01);
        vm.expectRevert(ISupplierPulsePlus.BadRules.selector);
        pulse.createOrder{value: 1 ether}(1, LEI, supplier, 0, _amounts(1), _dues(1, NOW, 0), TTL, 0x02);
        vm.expectRevert(ISupplierPulsePlus.BadRules.selector);
        pulse.createOrder{value: 1 ether}(0, CH_ID, supplier, 0, _amounts(1), _dues(1, NOW, 0), TTL, 0x80);
    }

    function test_badSource() public {
        vm.expectRevert(ISupplierPulsePlus.BadSource.selector);
        pulse.createOrder{value: 1 ether}(2, CH_ID, supplier, 0, _amounts(1), _dues(1, NOW, 0), TTL, 0);
        vm.expectRevert(ISupplierPulsePlus.BadSource.selector);
        pulse.airnodeOf(2);
    }

    function test_badOrder() public {
        uint256[] memory a = _amounts(2);
        uint64[] memory d = _dues(2, NOW, 10);
        bytes4 e = ISupplierPulsePlus.BadOrder.selector;

        vm.expectRevert(e); // wrong value
        pulse.createOrder{value: 1 ether}(0, CH_ID, supplier, 0, a, d, TTL, 0);
        vm.expectRevert(e); // empty list
        pulse.createOrder{value: 0}(0, CH_ID, supplier, 0, new uint256[](0), new uint64[](0), TTL, 0);
        vm.expectRevert(e); // zero supplier
        pulse.createOrder{value: 3 ether}(0, CH_ID, payable(address(0)), 0, a, d, TTL, 0);
        vm.expectRevert(e); // length mismatch
        pulse.createOrder{value: 3 ether}(0, CH_ID, supplier, 0, a, _dues(1, NOW, 0), TTL, 0);
        vm.expectRevert(e); // permitTtl 0
        pulse.createOrder{value: 3 ether}(0, CH_ID, supplier, 0, a, d, 0, 0);

        uint256[] memory zero = _amounts(2);
        zero[1] = 0;
        vm.expectRevert(e); // a zero amount
        pulse.createOrder{value: 1 ether}(0, CH_ID, supplier, 0, zero, d, TTL, 0);

        uint64[] memory down = _dues(2, NOW + 10, 0);
        down[1] = uint64(NOW);
        vm.expectRevert(e); // decreasing due dates
        pulse.createOrder{value: 3 ether}(0, CH_ID, supplier, 0, a, down, TTL, 0);

        // equal due dates are fine
        pulse.createOrder{value: 3 ether}(0, CH_ID, supplier, 0, a, _dues(2, NOW, 0), TTL, 0);
    }

    function test_unknownOrder() public {
        vm.expectRevert(ISupplierPulsePlus.BadOrder.selector);
        pulse.release(7);
        vm.expectRevert(ISupplierPulsePlus.BadOrder.selector);
        pulse.orderStatus(0);
    }

    function test_approveOnlyBuyerAndInRange() public {
        uint256 id = _order(0, CH_ID, 2, 0x06);
        vm.prank(stranger);
        vm.expectRevert(ISupplierPulsePlus.NotAuthorized.selector);
        pulse.approveMilestone(id, 0);
        vm.expectRevert(ISupplierPulsePlus.BadOrder.selector);
        pulse.approveMilestone(id, 2);
    }

    function test_orderViews() public {
        uint256 id = pulse.createOrder{value: 3 ether}(
            0, CH_ID, supplier, keccak256("PO-9"), _amounts(2), _dues(2, NOW + 100, 50), TTL, 0x04
        );
        pulse.approveMilestone(id, 1);
        _checkInfo(id);
        _checkMilestonesAndStatus(id);
        assertEq(pulse.ordersLength(), 1, "length");
    }

    function _checkInfo(uint256 id) internal view {
        (address b, address s, uint8 src, string memory sid, bytes32 req, bytes32 ref, uint64 ttl, uint8 rules) =
            pulse.orderInfo(id);
        assertTrue(b == address(this) && s == supplier && src == 0, "parties");
        assertTrue(keccak256(bytes(sid)) == keccak256(bytes(CH_ID)) && req == CH_REQ, "id and request");
        assertTrue(ref == keccak256("PO-9") && ttl == TTL && rules == 0x04, "ref ttl rules");
    }

    function _checkMilestonesAndStatus(uint256 id) internal view {
        {
            (uint256[] memory a, uint64[] memory d, bool[] memory ap) = pulse.orderMilestones(id);
            assertTrue(a[1] == 2 ether && d[1] == NOW + 150 && !ap[0] && ap[1], "milestones");
        }
        {
            (uint8 st, uint256 paid, uint256 rem, uint256 next, uint256 ms,, bool pv,) = pulse.orderStatus(id);
            assertTrue(st == 0 && paid == 0 && rem == 3 ether && next == 0 && ms == 2 && !pv, "status");
        }
        (uint64 due, bool appr, uint8 f, uint64 heldAt, uint64 autoAt, uint8 tier) = pulse.orderSchedule(id);
        assertTrue(due == NOW + 100 && !appr && f == 0 && heldAt == 0 && autoAt == 0 && tier == 0, "schedule");
    }

    // ------------------------------------------------------ Companies House

    function test_chCleanIssuesPermit() public {
        uint256 id = _order(0, CH_ID, 2, 0x06);
        assertTrue(_submit(id, _chClean(), NOW), "clean");
        (,,,,, uint64 until, bool pv, uint256 last) = pulse.orderStatus(id);
        assertTrue(pv && until == NOW + TTL && last == NOW, "permit");
        assertEq(_failed(id), 0, "no failed rules");
    }

    function test_chEachRuleFailsAlone() public {
        bytes[2] memory data = [_ch(true, false, "active"), _ch(false, true, "active")];
        uint8[2] memory bit = [0x02, 0x04];
        for (uint256 i = 0; i < 2; i++) {
            uint256 id = _order(0, CH_ID, 2, 0x06);
            assertTrue(!_submit(id, data[i], NOW - 3 + i), "held");
            assertEq(_failed(id), bit[i], "exact failedRules");
            assertEq(_state(id), 1, "state held");
        }
    }

    function test_chLiquidationSetsBaseBit() public {
        uint256 id = _order(0, CH_ID, 2, 0x06);
        assertTrue(!_submit(id, _ch(true, false, "liquidation"), NOW), "held");
        assertEq(_failed(id), 0x80 | 0x02, "base plus enabled failures");

        uint256 id2 = _order(0, CH_ID, 1, 0);
        assertTrue(!_submit(id2, _ch(false, false, "dissolved"), NOW - 1), "held, no rules");
        assertEq(_failed(id2), 0x80, "base only");
    }

    function test_chDisabledRuleIgnored() public {
        uint256 id = _order(0, CH_ID, 2, 0x02); // only accounts rule
        assertTrue(_submit(id, _ch(false, true, "active"), NOW), "confirmation ignored");
        // a disabled rule's field may even be missing
        uint256 id2 = _order(0, CH_ID, 1, 0);
        assertTrue(_submit(id2, bytes('{"status":"active"}'), NOW - 1), "status only");
    }

    function test_chKeyOrderAndSpacesDoNotMatter() public {
        uint256 id = _order(0, CH_ID, 1, 0x06);
        bytes memory data =
            bytes('{"status": "active", "confirmation_overdue": false, "accounts_overdue": false}');
        assertTrue(_submit(id, data, NOW), "parsed by key");
    }

    function test_chMissingEnabledFieldReverts() public {
        uint256 id = _order(0, CH_ID, 1, 0x02);
        bytes memory data = bytes('{"status":"active"}');
        vm.expectRevert(JsonFields.KeyNotFound.selector);
        pulse.submitEvidence(id, CH_REQ, NOW, data, _sign(CH_KEY, CH_REQ, NOW, data));
    }

    // ------------------------------------------------------------------ GLEIF

    function test_gleifClean() public {
        uint256 id = _order(1, LEI, 2, 0x08);
        assertTrue(_submit(id, _gleif("ACTIVE", "ISSUED"), NOW), "clean");
    }

    function test_gleifLapsedIsHeld() public {
        uint256 id = _order(1, LEI, 2, 0x08);
        assertTrue(!_submit(id, _gleif("ACTIVE", "LAPSED"), NOW), "held");
        assertEq(_failed(id), 0x08, "lapsed");
        // without the rule, LAPSED is fine
        uint256 id2 = _order(1, LEI, 1, 0);
        assertTrue(_submit(id2, _gleif("ACTIVE", "LAPSED"), NOW - 1), "rule off");
    }

    function test_gleifInactive() public {
        uint256 id = _order(1, LEI, 2, 0x08);
        assertTrue(!_submit(id, _gleif("INACTIVE", "ISSUED"), NOW), "held");
        assertEq(_failed(id), 0x80, "base");
    }

    function test_gleifUsesItsOwnAirnode() public {
        uint256 id = _order(1, LEI, 1, 0x08);
        bytes memory data = _gleif("ACTIVE", "ISSUED");
        vm.expectRevert(abi.encodeWithSelector(ISupplierPulsePlus.WrongSigner.selector, vm.addr(CH_KEY)));
        pulse.submitEvidence(id, LEI_REQ, NOW, data, _sign(CH_KEY, LEI_REQ, NOW, data));
    }

    // ----------------------------------------------------------------- tamper

    function test_tamperEditedValue() public {
        uint256 id = _order(0, CH_ID, 1, 0x06);
        bytes memory sig = _sign(CH_KEY, CH_REQ, NOW, _ch(false, false, "liquidation"));
        bytes memory edited = _ch(false, false, "active");
        // the recovered address is some random one, so check the error selector only
        try pulse.submitEvidence(id, CH_REQ, NOW, edited, sig) {
            revert("accepted");
        } catch (bytes memory err) {
            assertTrue(bytes4(err) == ISupplierPulsePlus.WrongSigner.selector, "WrongSigner");
        }
    }

    function test_tamperStale() public {
        uint256 id = _order(0, CH_ID, 1, 0x06);
        bytes memory data = _chClean();
        uint256 ts = NOW - MAX_AGE - 1;
        vm.expectRevert(abi.encodeWithSelector(ISupplierPulsePlus.StaleResponse.selector, ts, NOW));
        pulse.submitEvidence(id, CH_REQ, ts, data, _sign(CH_KEY, CH_REQ, ts, data));
        assertTrue(_submit(id, data, NOW - MAX_AGE), "exactly maxAge is fine");
    }

    function test_tamperFuture() public {
        uint256 id = _order(0, CH_ID, 1, 0x06);
        bytes memory data = _chClean();
        uint256 ts = NOW + 61;
        vm.expectRevert(abi.encodeWithSelector(ISupplierPulsePlus.FutureResponse.selector, ts, NOW));
        pulse.submitEvidence(id, CH_REQ, ts, data, _sign(CH_KEY, CH_REQ, ts, data));
        assertTrue(_submit(id, data, NOW + 60), "60 s skew is fine");
    }

    function test_tamperOtherRequest() public {
        uint256 id = _order(0, CH_ID, 1, 0x06);
        bytes memory data = _chClean();
        bytes32 other = pulse.requestHashFor(0, "00000001");
        vm.expectRevert(abi.encodeWithSelector(ISupplierPulsePlus.WrongRequest.selector, other, CH_REQ));
        pulse.submitEvidence(id, other, NOW, data, _sign(CH_KEY, other, NOW, data));
    }

    function test_tamperChResponseOnGleifOrder() public {
        uint256 id = _order(1, LEI, 1, 0x08);
        bytes memory data = _chClean();
        vm.expectRevert(abi.encodeWithSelector(ISupplierPulsePlus.WrongRequest.selector, CH_REQ, LEI_REQ));
        pulse.submitEvidence(id, CH_REQ, NOW, data, _sign(CH_KEY, CH_REQ, NOW, data));
    }

    function test_tamperWrongKey() public {
        uint256 id = _order(0, CH_ID, 1, 0x06);
        bytes memory data = _chClean();
        vm.expectRevert(abi.encodeWithSelector(ISupplierPulsePlus.WrongSigner.selector, vm.addr(ATTACKER_KEY)));
        pulse.submitEvidence(id, CH_REQ, NOW, data, _sign(ATTACKER_KEY, CH_REQ, NOW, data));
    }

    function test_tamperReplay() public {
        uint256 id = _order(0, CH_ID, 2, 0x06);
        bytes memory data = _chClean();
        bytes memory sig = _sign(CH_KEY, CH_REQ, NOW, data);
        pulse.submitEvidence(id, CH_REQ, NOW, data, sig);
        bytes32 d = AirnodeVerifier.digest(CH_REQ, NOW, data);
        assertTrue(pulse.usedDigests(d), "digest marked");
        vm.expectRevert(abi.encodeWithSelector(ISupplierPulsePlus.Replayed.selector, d));
        pulse.submitEvidence(id, CH_REQ, NOW, data, sig);
    }

    function test_tamperReplayAcrossOrders() public {
        uint256 a = _order(0, CH_ID, 1, 0x06);
        uint256 b = _order(0, CH_ID, 1, 0x06);
        bytes memory data = _chClean();
        bytes memory sig = _sign(CH_KEY, CH_REQ, NOW, data);
        pulse.submitEvidence(a, CH_REQ, NOW, data, sig);
        vm.expectRevert(
            abi.encodeWithSelector(ISupplierPulsePlus.Replayed.selector, AirnodeVerifier.digest(CH_REQ, NOW, data))
        );
        pulse.submitEvidence(b, CH_REQ, NOW, data, sig);
    }

    function test_tamperNotNewer() public {
        uint256 id = _order(0, CH_ID, 2, 0x06);
        _submit(id, _chClean(), NOW);
        bytes memory older = _ch(false, false, "active ");
        vm.expectRevert(abi.encodeWithSelector(ISupplierPulsePlus.NotNewer.selector, NOW - 10, NOW));
        pulse.submitEvidence(id, CH_REQ, NOW - 10, older, _sign(CH_KEY, CH_REQ, NOW - 10, older));
    }

    function test_tamperHighS() public {
        uint256 id = _order(0, CH_ID, 1, 0x06);
        bytes memory data = _chClean();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(CH_KEY, AirnodeVerifier.ethSignedHash(AirnodeVerifier.digest(CH_REQ, NOW, data)));
        bytes memory flipped = abi.encodePacked(r, bytes32(N - uint256(s)), v == 27 ? uint8(28) : uint8(27));
        vm.expectRevert(AirnodeVerifier.InvalidSignatureS.selector);
        pulse.submitEvidence(id, CH_REQ, NOW, data, flipped);
    }

    function test_heldOrderRejectsEvidence() public {
        uint256 id = _order(0, CH_ID, 2, 0x06);
        _submit(id, _ch(false, false, "liquidation"), NOW - 5);
        bytes memory data = _chClean();
        vm.expectRevert(abi.encodeWithSelector(ISupplierPulsePlus.NotActive.selector, uint8(1)));
        pulse.submitEvidence(id, CH_REQ, NOW, data, _sign(CH_KEY, CH_REQ, NOW, data));
    }

    // ---------------------------------------------------------------- permits

    function test_tierNeverExtendsPermit() public {
        // Premium needs 6 counted clean records; gap 60 s between counted ones
        uint256 id = _order(0, CH_ID, 1, 0x06);
        bytes32 key = pulse.supplierKeyOf(0, CH_ID);
        for (uint256 i = 0; i < 6; i++) {
            vm.warp(NOW + i * GAP);
            _submit(id, _chClean(), NOW + i * GAP);
            (,,,,, uint64 until,,) = pulse.orderStatus(id);
            assertEq(until, NOW + i * GAP + TTL, "always permitTtl");
        }
        assertEq(_tier(key), 2, "premium");
    }

    function test_permitExpired() public {
        uint256 id = _order(0, CH_ID, 1, 0x06);
        _submit(id, _chClean(), NOW);
        pulse.approveMilestone(id, 0);
        vm.warp(NOW + TTL + 1);
        vm.expectRevert(abi.encodeWithSelector(ISupplierPulsePlus.PermitExpired.selector, NOW + TTL, NOW + TTL + 1));
        pulse.release(id);
    }

    function test_permitUsedUpAndNextNeedsEvidence() public {
        uint256 id = _order(0, CH_ID, 2, 0x06);
        pulse.approveMilestone(id, 0);
        pulse.approveMilestone(id, 1);
        assertEq(_check(id, _chClean(), NOW), 0, "paid");
        vm.expectRevert(abi.encodeWithSelector(ISupplierPulsePlus.NoValidPermit.selector, 1));
        pulse.release(id);
        vm.warp(NOW + 1);
        assertEq(_check(id, _chClean(), NOW + 1), 0, "paid again");
        assertEq(supplier.balance, 3 ether, "both paid");
        assertEq(_state(id), 2, "closed");
    }

    function test_noPermitAtAll() public {
        uint256 id = _order(0, CH_ID, 1, 0x06);
        vm.expectRevert(abi.encodeWithSelector(ISupplierPulsePlus.NoValidPermit.selector, 0));
        pulse.release(id);
    }

    function test_newerCleanRecordReplacesPermit() public {
        uint256 id = _order(0, CH_ID, 1, 0x06);
        _submit(id, _chClean(), NOW - 100);
        _submit(id, _chClean(), NOW);
        (,,,,, uint64 until,,) = pulse.orderStatus(id);
        assertEq(until, NOW + TTL, "replaced");
    }

    // ---------------------------------------------------------------- payment

    function test_notDueThenPaid() public {
        uint256 id = pulse.createOrder{value: 1 ether}(
            0, CH_ID, supplier, 0, _amounts(1), _dues(1, NOW + 100, 0), TTL, 0x06
        );
        pulse.approveMilestone(id, 0);
        _submit(id, _chClean(), NOW);
        vm.expectRevert(abi.encodeWithSelector(ISupplierPulsePlus.NotDue.selector, NOW + 100, NOW));
        pulse.release(id);
        vm.warp(NOW + 100);
        pulse.release(id);
        assertEq(supplier.balance, 1 ether, "paid at due date");
    }

    function test_notApproved() public {
        uint256 id = _order(0, CH_ID, 1, 0x06);
        _submit(id, _chClean(), NOW);
        vm.expectRevert(abi.encodeWithSelector(ISupplierPulsePlus.NotApproved.selector, 0));
        pulse.release(id);
    }

    function test_checkAndReleaseOutcomes() public {
        // 1 AwaitingApproval
        uint256 a = _order(0, CH_ID, 1, 0x06);
        assertEq(_check(a, _chClean(), NOW - 4), 1, "awaiting approval");
        // 2 NotDue
        uint256 b = pulse.createOrder{value: 1 ether}(
            0, CH_ID, supplier, 0, _amounts(1), _dues(1, NOW + 100, 0), TTL, 0x06
        );
        pulse.approveMilestone(b, 0);
        assertEq(_check(b, _chClean(), NOW - 3), 2, "not due");
        assertEq(supplier.balance, 0, "nothing paid yet");
        // 3 Held
        uint256 c = _order(0, CH_ID, 1, 0x06);
        assertEq(_check(c, _ch(true, false, "active"), NOW - 2), 3, "held");
        // 0 Paid
        uint256 d = _order(0, CH_ID, 1, 0x06);
        pulse.approveMilestone(d, 0);
        assertEq(_check(d, _chClean(), NOW - 1), 0, "paid");
        assertEq(supplier.balance, 1 ether, "supplier paid");
    }

    function test_checkAndReleaseRevertsOnVerificationFailure() public {
        uint256 id = _order(0, CH_ID, 1, 0x06);
        bytes memory data = _chClean();
        vm.expectRevert(abi.encodeWithSelector(ISupplierPulsePlus.WrongSigner.selector, vm.addr(ATTACKER_KEY)));
        pulse.checkAndRelease(id, CH_REQ, NOW, data, _sign(ATTACKER_KEY, CH_REQ, NOW, data));
    }

    function test_orderStatusAfterPartialPayment() public {
        uint256 id = _order(0, CH_ID, 3, 0x06);
        pulse.approveMilestone(id, 0);
        _check(id, _chClean(), NOW);
        (uint8 st, uint256 paid, uint256 rem, uint256 next,,, bool pv,) = pulse.orderStatus(id);
        assertTrue(st == 0 && paid == 1 ether && rem == 5 ether && next == 1 && !pv, "after first");
        (uint64 due,,,,,) = pulse.orderSchedule(id);
        assertEq(due, NOW, "next due");
    }

    // ------------------------------------------------------------------ tiers

    function test_streakCountsOnlyAfterGap() public {
        uint256 id = _order(0, CH_ID, 1, 0x06);
        bytes32 key = pulse.supplierKeyOf(0, CH_ID);
        _submit(id, _chClean(), NOW - 30);
        _submit(id, _chClean(), NOW - 1); // 29 s later: not counted
        assertEq(_streak(key), 1, "one counted");
        vm.warp(NOW + 30);
        _submit(id, _chClean(), NOW + 30); // 60 s after the counted one
        assertEq(_streak(key), 2, "two counted");
        (, uint32 checks,,,,,) = pulse.supplierRecord(key);
        assertEq(checks, 3, "all checks counted");
    }

    function test_streakResetsOnFailureAndTiersEmit() public {
        bytes32 key = pulse.supplierKeyOf(0, CH_ID);
        uint256 id = _order(0, CH_ID, 1, 0x06);
        for (uint256 i = 0; i < 3; i++) {
            vm.warp(NOW + i * GAP);
            if (i == 2) {
                vmE.expectEmit(true, false, false, true, address(pulse));
                emit ISupplierPulsePlus.TierChanged(key, 0, 1, 3);
            }
            _submit(id, _chClean(), NOW + i * GAP);
        }
        assertEq(_tier(key), 1, "trusted");
        for (uint256 i = 3; i < 6; i++) {
            vm.warp(NOW + i * GAP);
            if (i == 5) {
                vmE.expectEmit(true, false, false, true, address(pulse));
                emit ISupplierPulsePlus.TierChanged(key, 1, 2, 6);
            }
            _submit(id, _chClean(), NOW + i * GAP);
        }
        assertEq(_tier(key), 2, "premium");

        // a failure on another order of the same supplier resets the shared record
        uint256 other = _order(0, CH_ID, 1, 0x06);
        vm.warp(NOW + 6 * GAP);
        vmE.expectEmit(true, false, false, true, address(pulse));
        emit ISupplierPulsePlus.TierChanged(key, 2, 0, 0);
        _submit(other, _ch(false, false, "liquidation"), NOW + 6 * GAP);
        (uint32 streak,, uint32 failures,,, uint64 failedAt, uint8 tier) = pulse.supplierRecord(key);
        assertTrue(streak == 0 && failures == 1 && tier == 0 && failedAt == NOW + 6 * GAP, "reset");
        (,,,,, uint8 t) = pulse.orderSchedule(id);
        assertEq(t, 0, "first order sees the shared tier");
    }

    function test_twoOrdersShareSupplierRecord() public {
        uint256 a = _order(0, CH_ID, 1, 0x06);
        uint256 b = _order(0, CH_ID, 1, 0x06);
        bytes32 key = pulse.supplierKeyOf(0, CH_ID);
        _submit(a, _chClean(), NOW - GAP);
        _submit(b, _chClean(), NOW);
        assertEq(_streak(key), 2, "shared streak");
        // a different registry id is a different supplier
        assertTrue(pulse.supplierKeyOf(1, LEI) != key, "other key");
    }

    function test_olderRecordDoesNotMoveHistory() public {
        uint256 a = _order(0, CH_ID, 1, 0x06);
        uint256 b = _order(0, CH_ID, 1, 0x06);
        bytes32 key = pulse.supplierKeyOf(0, CH_ID);
        _submit(a, _chClean(), NOW);
        // b gets an older record: it serves b's own order, but the history stays
        assertTrue(_submit(b, _ch(false, false, "liquidation"), NOW - 10) == false, "b held");
        (uint32 streak, uint32 checks, uint32 failures,, uint64 lastCheckAt, uint64 failedAt,) = pulse.supplierRecord(key);
        assertTrue(streak == 1 && checks == 1 && failures == 0 && lastCheckAt == NOW && failedAt == 0, "unchanged");
        assertEq(_state(a), 0, "a still active");
    }

    function test_ruleOnlyFailureKeepsStreak() public {
        uint256 a = _order(0, CH_ID, 1, 0x02);
        bytes32 key = pulse.supplierKeyOf(0, CH_ID);
        _submit(a, _chClean(), NOW - GAP);
        uint256 b = _order(0, CH_ID, 1, 0x02);
        assertTrue(!_submit(b, _ch(true, false, "active"), NOW), "b held for accounts");
        (uint32 streak, uint32 checks, uint32 failures,,, uint64 failedAt,) = pulse.supplierRecord(key);
        assertTrue(streak == 2 && checks == 2 && failures == 0 && failedAt == 0, "base passed, counted");
    }

    // ---------------------------------------------------- supplier-wide stop

    /// order a has a valid permit, then order b of the same supplier shows liquidation
    function _stopSetup() internal returns (uint256 a, uint256 b) {
        a = _order(0, CH_ID, 2, 0x06);
        b = _order(0, CH_ID, 2, 0x06);
        pulse.approveMilestone(a, 0);
        _submit(a, _chClean(), NOW - 20);
        _submit(b, _ch(false, false, "liquidation"), NOW - 10);
    }

    function test_supplierStopBlocksOtherPermit() public {
        (uint256 a,) = _stopSetup();
        assertEq(_failedAt(pulse.supplierKeyOf(0, CH_ID)), NOW - 10, "failure stored");
        vm.expectRevert(abi.encodeWithSelector(ISupplierPulsePlus.SupplierFailed.selector, NOW - 10));
        pulse.release(a);
    }

    function test_applySupplierFailureHolds() public {
        (uint256 a,) = _stopSetup();
        vmE.expectEmit(true, false, false, true, address(pulse));
        emit ISupplierPulsePlus.OrderHeld(a, 0x80, 3 ether, uint64(NOW + GRACE));
        pulse.applySupplierFailure(a);
        assertEq(_state(a), 1, "held");
        assertEq(_failed(a), 0x80, "base label");
        vm.expectRevert(abi.encodeWithSelector(ISupplierPulsePlus.NotActive.selector, uint8(1)));
        pulse.applySupplierFailure(a);
    }

    function test_noNewerFailure() public {
        _stopSetup();
        // an order of the failed supplier whose own last check is newer than the failure
        uint256 c = _order(0, CH_ID, 1, 0x06);
        _submit(c, _chClean(), NOW);
        vm.expectRevert(ISupplierPulsePlus.NoNewerFailure.selector);
        pulse.applySupplierFailure(c);
    }

    function test_cleanRecordOlderThanFailure() public {
        _stopSetup();
        uint256 c = _order(0, CH_ID, 1, 0x06);
        bytes memory data = _chClean();
        vm.expectRevert(abi.encodeWithSelector(ISupplierPulsePlus.SupplierFailed.selector, NOW - 10));
        pulse.submitEvidence(c, CH_REQ, NOW - 15, data, _sign(CH_KEY, CH_REQ, NOW - 15, data));
        assertTrue(_submit(c, data, NOW), "a newer clean record is fine");
    }

    function test_ruleOnlyFailureDoesNotStopOthers() public {
        uint256 a = _order(0, CH_ID, 1, 0x06);
        uint256 b = _order(0, CH_ID, 1, 0x02);
        pulse.approveMilestone(a, 0);
        _submit(a, _chClean(), NOW - 10);
        assertTrue(!_submit(b, _ch(true, false, "active"), NOW), "b held for its own rule");
        pulse.release(a);
        assertEq(supplier.balance, 1 ether, "a paid");
        uint256 c = _order(0, CH_ID, 1, 0x06);
        vm.expectRevert(ISupplierPulsePlus.NoNewerFailure.selector); // no base failure stored
        pulse.applySupplierFailure(c);
    }

    // ----------------------------------------------------------------- refund

    function _heldOrder() internal returns (uint256 id) {
        id = _order(0, CH_ID, 3, 0x06);
        pulse.approveMilestone(id, 0);
        _check(id, _chClean(), NOW - 10); // pays 1 ether
        _submit(id, _ch(false, false, "liquidation"), NOW); // holds 5 ether
    }

    function test_buyerRefundsAtOnce() public {
        uint256 id = _heldOrder();
        (,,, uint64 heldAt, uint64 autoAt,) = pulse.orderSchedule(id);
        assertTrue(heldAt == NOW && autoAt == NOW + GRACE, "hold times");
        uint256 before = address(this).balance;
        pulse.refundRemaining(id);
        assertEq(address(this).balance - before, 5 ether, "buyer refunded");
        assertEq(_state(id), 2, "closed");
        (,, uint256 rem,,,,,) = pulse.orderStatus(id);
        assertEq(rem, 0, "nothing left");
    }

    function test_strangerRefundAfterGrace() public {
        uint256 id = _heldOrder();
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(ISupplierPulsePlus.RefundNotYet.selector, NOW + GRACE));
        pulse.refundRemaining(id);

        vm.warp(NOW + GRACE);
        uint256 before = address(this).balance;
        vmE.expectEmit(true, false, false, true, address(pulse));
        emit ISupplierPulsePlus.OrderRefunded(id, address(this), 5 ether, stranger, false);
        vm.prank(stranger);
        pulse.refundRemaining(id);
        assertEq(address(this).balance - before, 5 ether, "money reached the buyer");
        assertEq(stranger.balance, 0, "stranger got nothing");
    }

    function test_refundClosedOrderNotRefundable() public {
        uint256 id = _heldOrder();
        pulse.refundRemaining(id);
        vm.expectRevert(ISupplierPulsePlus.NotRefundable.selector);
        pulse.refundRemaining(id); // no double refund
    }

    // no-data exit: two milestones due at NOW + 100 and NOW + 200, milestone 0 paid at its due date
    function _noDataOrder() internal returns (uint256 id) {
        id = pulse.createOrder{value: 3 ether}(
            0, CH_ID, supplier, 0, _amounts(2), _dues(2, NOW + 100, 100), TTL, 0x06
        );
        pulse.approveMilestone(id, 0);
        vm.warp(NOW + 100);
        _check(id, _chClean(), NOW + 100); // pays 1 ether
    }

    function test_noDataExit() public {
        uint256 id = _noDataOrder();
        vm.expectRevert(abi.encodeWithSelector(ISupplierPulsePlus.NotApproved.selector, 1));
        pulse.refundRemaining(id);

        pulse.approveMilestone(id, 1);
        (,,,, uint64 autoAt,) = pulse.orderSchedule(id);
        assertEq(autoAt, NOW + 200 + GRACE, "no-data exit time");
        vm.warp(NOW + 200 + GRACE - 1);
        vm.expectRevert(abi.encodeWithSelector(ISupplierPulsePlus.RefundNotYet.selector, NOW + 200 + GRACE));
        pulse.refundRemaining(id);

        vm.warp(NOW + 200 + GRACE);
        uint256 before = address(this).balance;
        vmE.expectEmit(true, false, false, true, address(pulse));
        emit ISupplierPulsePlus.OrderRefunded(id, address(this), 2 ether, stranger, true);
        vm.prank(stranger);
        pulse.refundRemaining(id);
        assertEq(address(this).balance - before, 2 ether, "remaining back to the buyer");
        assertEq(supplier.balance, 1 ether, "paid milestone stays paid");
        assertEq(_state(id), 2, "closed");
        vm.expectRevert(ISupplierPulsePlus.NotRefundable.selector);
        pulse.refundRemaining(id);
    }

    // C2.5 finding 1: a buyer who approves late cannot approve and refund in the same block
    function test_noDataExitCountsFromLateApproval() public {
        uint256 id = pulse.createOrder{value: 1 ether}(0, CH_ID, supplier, 0, _amounts(1), _dues(1, NOW, 0), TTL, 0x06);
        vm.warp(NOW + GRACE); // due + grace has passed, nothing approved yet
        pulse.approveMilestone(id, 0);
        (,,,, uint64 autoAt,) = pulse.orderSchedule(id);
        assertEq(autoAt, NOW + 2 * GRACE, "grace counts from the approval");
        vm.expectRevert(abi.encodeWithSelector(ISupplierPulsePlus.RefundNotYet.selector, NOW + 2 * GRACE));
        pulse.refundRemaining(id);

        // the supplier still gets paid with a fresh record inside the new grace
        vm.warp(NOW + 2 * GRACE - 1);
        assertEq(_check(id, _chClean(), NOW + 2 * GRACE - 1), 0, "paid");
        assertEq(supplier.balance, 1 ether, "supplier paid");
    }

    function test_noDataExitAfterLateApprovalAndGrace() public {
        uint256 id = pulse.createOrder{value: 1 ether}(0, CH_ID, supplier, 0, _amounts(1), _dues(1, NOW, 0), TTL, 0x06);
        vm.warp(NOW + 500);
        pulse.approveMilestone(id, 0);
        vm.warp(NOW + 500 + GRACE);
        uint256 before = address(this).balance;
        vm.prank(stranger);
        pulse.refundRemaining(id);
        assertEq(address(this).balance - before, 1 ether, "refunded after the full grace");
    }

    function test_reapprovingDoesNotMoveTheExit() public {
        uint256 id = _noDataOrder();
        pulse.approveMilestone(id, 1); // at NOW + 100, before the due date NOW + 200
        vm.warp(NOW + 250);
        pulse.approveMilestone(id, 1); // already approved: the first approval time stays
        (,,,, uint64 autoAt,) = pulse.orderSchedule(id);
        assertEq(autoAt, NOW + 200 + GRACE, "due date + grace");
    }

    // C2.5 finding 2: permitTtl >= maxAge, so the oldest accepted record still yields a usable permit
    function test_createOrderRequiresTtlAtLeastMaxAge() public {
        vm.expectRevert(ISupplierPulsePlus.BadOrder.selector);
        pulse.createOrder{value: 1 ether}(0, CH_ID, supplier, 0, _amounts(1), _dues(1, NOW, 0), uint64(MAX_AGE - 1), 0x06);
        uint256 id = pulse.createOrder{value: 1 ether}(
            0, CH_ID, supplier, 0, _amounts(1), _dues(1, NOW, 0), uint64(MAX_AGE), 0x06
        );
        pulse.approveMilestone(id, 0);
        assertEq(_check(id, _chClean(), NOW - MAX_AGE), 0, "oldest accepted record pays");
        assertEq(supplier.balance, 1 ether, "supplier paid");
    }

    function test_noDataExitBlockedByValidPermit() public {
        uint256 id = _noDataOrder();
        pulse.approveMilestone(id, 1);
        vm.warp(NOW + 200 + GRACE);
        _submit(id, _chClean(), NOW + 200 + GRACE); // fresh permit for milestone 1
        vm.expectRevert(ISupplierPulsePlus.NotRefundable.selector);
        pulse.refundRemaining(id);
        (,,,, uint64 autoAt,) = pulse.orderSchedule(id);
        assertEq(autoAt, 0, "no exit while a permit is valid");
    }

    function test_heldOrderCannotRelease() public {
        uint256 id = _heldOrder();
        vm.expectRevert(abi.encodeWithSelector(ISupplierPulsePlus.NotActive.selector, uint8(1)));
        pulse.release(id);
    }

    // ----------------------------------------------------------------- events

    function test_eventsCreateApprove() public {
        bytes32 key = pulse.supplierKeyOf(0, CH_ID);
        vmE.expectEmit(true, true, true, true, address(pulse));
        emit ISupplierPulsePlus.OrderCreated(
            0, address(this), key, supplier, 0, CH_ID, CH_REQ, keccak256("PO-1001"), 3 ether, 0x06
        );
        uint256 id = _order(0, CH_ID, 2, 0x06);
        vmE.expectEmit(true, false, false, true, address(pulse));
        emit ISupplierPulsePlus.MilestoneApproved(id, 1);
        pulse.approveMilestone(id, 1);
    }

    function test_eventsCleanPath() public {
        uint256 id = _order(0, CH_ID, 2, 0x06);
        pulse.approveMilestone(id, 0);
        bytes32 key = pulse.supplierKeyOf(0, CH_ID);
        bytes memory data = _chClean();
        bytes32 d = AirnodeVerifier.digest(CH_REQ, NOW, data);
        bytes memory sig = _sign(CH_KEY, CH_REQ, NOW, data);

        vmE.expectEmit(true, true, false, true, address(pulse));
        emit ISupplierPulsePlus.EvidenceAccepted(id, key, true, 0, NOW, d, address(this), data);
        vmE.expectEmit(true, false, false, true, address(pulse));
        emit ISupplierPulsePlus.PermitIssued(id, 0, 1 ether, uint64(NOW + TTL), d);
        vmE.expectEmit(true, false, false, true, address(pulse));
        emit ISupplierPulsePlus.MilestonePaid(id, 0, supplier, 1 ether, d);
        pulse.checkAndRelease(id, CH_REQ, NOW, data, sig);
    }

    function test_eventsHeldPath() public {
        uint256 id = _order(0, CH_ID, 2, 0x06);
        bytes32 key = pulse.supplierKeyOf(0, CH_ID);
        bytes memory data = _ch(true, false, "active");
        bytes32 d = AirnodeVerifier.digest(CH_REQ, NOW, data);
        vmE.expectEmit(true, true, false, true, address(pulse));
        emit ISupplierPulsePlus.EvidenceAccepted(id, key, false, 0x02, NOW, d, address(this), data);
        vmE.expectEmit(true, false, false, true, address(pulse));
        emit ISupplierPulsePlus.OrderHeld(id, 0x02, 3 ether, uint64(NOW + GRACE));
        pulse.submitEvidence(id, CH_REQ, NOW, data, _sign(CH_KEY, CH_REQ, NOW, data));
    }

    // ----------------------------------- real AirnodeHub responses (Companies House)

    address constant CH_AIRNODE = 0x392228E5CCA260313e5ed337Ed3561B59A1e4bFF;

    // real signed getCompanyProfile records with the v1.1 projection (30 Oct 17:14 CET, paid via x402;
    // api3/fixtures/ on emre/plus-data)
    uint256 constant CH_A_TS = 1793376875; // 03778796: active, nothing overdue
    bytes constant CH_A_SIG =
        hex"7b0521dc986c08bf7e9faa400c90074f8f8dc5465b1474e6580d16aa577b85f556f2fd360466cdea2c91d8da421b560393905a718b4f4271536a174f55d001721c";
    uint256 constant CH_B_TS = 1793376878; // 07418033: liquidation, accounts and confirmation overdue
    bytes constant CH_B_SIG =
        hex"e57b047c3baaeeb4e0d8af6f533cf4d5349de20bc2495b7fba221b515cab8a193bb343065f185ee0a5484dc3f25294ced3e6160e6bd3cbb6584e610239cd23e51b";
    uint256 constant CH_C_TS = 1793376879; // 09729896: active, accounts and confirmation overdue
    bytes constant CH_C_SIG =
        hex"6267dce79feaf28e4ec3b9e686101e05cda4f7bd338148d9c465ae644c165c147966ac05cdf7070c5d04bb02292ad829073f5d4cd0d49704ccf912a7c7b6d9941b";

    function _chA() internal pure returns (bytes memory) {
        return bytes('{"accounts_overdue":false,"confirmation_overdue":false,"status":"active"}');
    }

    function _chB() internal pure returns (bytes memory) {
        return bytes('{"accounts_overdue":true,"confirmation_overdue":true,"status":"liquidation"}');
    }

    function _chC() internal pure returns (bytes memory) {
        return bytes('{"accounts_overdue":true,"confirmation_overdue":true,"status":"active"}');
    }

    /// A contract that trusts the real Companies House Airnode, at `ts + 10`.
    function _chLive(uint256 ts) internal returns (SupplierPulsePlus live) {
        vm.warp(ts + 10);
        live = new SupplierPulsePlus(CH_AIRNODE, vm.addr(GLEIF_KEY), MAX_AGE, GAP, GRACE);
    }

    function _chOrder(SupplierPulsePlus live, string memory id, uint8 rules) internal returns (uint256 orderId) {
        orderId = live.createOrder{value: 1 ether}(0, id, supplier, 0, _amounts(1), _dues(1, block.timestamp - 10, 0), TTL, rules);
        live.approveMilestone(orderId, 0);
    }

    function test_realChRequestHashes() public {
        SupplierPulsePlus live = _chLive(CH_A_TS);
        assertTrue(live.requestHashFor(0, "03778796") == 0xa6d1feccef225c1377ec0a5ec66988df0d5bfc02741d13a1b394d66c7897f452, "A");
        assertTrue(live.requestHashFor(0, "07418033") == 0xb3d470a001a5692f90b229b49c61359e74e5578776caf091600340de893667d6, "B");
        assertTrue(live.requestHashFor(0, "09729896") == 0x6e84889a218993dcdaaa5e41a15b5b1bba283e48ca36763248620abbe2f17f0f, "C");
    }

    function test_realChCleanSupplierIsPaid() public {
        SupplierPulsePlus live = _chLive(CH_A_TS);
        uint256 id = _chOrder(live, "03778796", 0x06);
        assertEq(live.checkAndRelease(id, live.requestHashFor(0, "03778796"), CH_A_TS, _chA(), CH_A_SIG), 0, "A paid");
        assertEq(supplier.balance, 1 ether, "supplier paid");
    }

    function test_realChLiquidationIsHeld() public {
        SupplierPulsePlus live = _chLive(CH_B_TS);
        uint256 id = _chOrder(live, "07418033", 0x06);
        assertEq(live.checkAndRelease(id, live.requestHashFor(0, "07418033"), CH_B_TS, _chB(), CH_B_SIG), 3, "B held");
        (,, uint8 f,,,) = live.orderSchedule(id);
        assertEq(f, 0x80 | 0x02 | 0x04, "status, accounts and confirmation labels");
        assertEq(supplier.balance, 0, "not paid");
    }

    function test_realChAccountsOverdueIsHeld() public {
        // order C: the status alone would pay, the buyer's accounts rule holds it
        SupplierPulsePlus live = _chLive(CH_C_TS);
        uint256 id = _chOrder(live, "09729896", 0x02);
        assertEq(live.checkAndRelease(id, live.requestHashFor(0, "09729896"), CH_C_TS, _chC(), CH_C_SIG), 3, "C held");
        (,, uint8 f,,,) = live.orderSchedule(id);
        assertEq(f, 0x02, "accounts overdue only");
        // the same record pays an order without that rule
        uint256 plain = _chOrder(live, "09729896", 0);
        bytes32 req = live.requestHashFor(0, "09729896");
        vm.expectRevert(abi.encodeWithSelector(ISupplierPulsePlus.Replayed.selector, AirnodeVerifier.digest(req, CH_C_TS, _chC())));
        live.checkAndRelease(plain, req, CH_C_TS, _chC(), CH_C_SIG); // but a record is settled once
    }

    function test_realChSupplierWideStop() public {
        // B2 in the demo: a second order of the liquidated supplier is held without a new fetch
        SupplierPulsePlus live = _chLive(CH_B_TS);
        uint256 b = _chOrder(live, "07418033", 0x06);
        uint256 b2 = _chOrder(live, "07418033", 0x06);
        live.checkAndRelease(b, live.requestHashFor(0, "07418033"), CH_B_TS, _chB(), CH_B_SIG);
        live.applySupplierFailure(b2);
        (uint8 st,,,,,,,) = live.orderStatus(b2);
        assertEq(st, 1, "B2 held");
    }

    function test_realChResponseForAnotherCompany() public {
        // the genuine clean record of A, submitted unchanged to order C (tamper case c)
        SupplierPulsePlus live = _chLive(CH_A_TS);
        uint256 id = _chOrder(live, "09729896", 0x02);
        bytes32 req = live.requestHashFor(0, "03778796");
        vm.expectRevert(abi.encodeWithSelector(ISupplierPulsePlus.WrongRequest.selector, req, live.requestHashFor(0, "09729896")));
        live.submitEvidence(id, req, CH_A_TS, _chA(), CH_A_SIG);
    }

    function test_realChEditedValue() public {
        // B's real signature with "liquidation" edited to "active" (tamper case a)
        SupplierPulsePlus live = _chLive(CH_B_TS);
        uint256 id = _chOrder(live, "07418033", 0x06);
        bytes memory edited = bytes('{"accounts_overdue":true,"confirmation_overdue":true,"status":"active"}');
        try live.submitEvidence(id, live.requestHashFor(0, "07418033"), CH_B_TS, edited, CH_B_SIG) {
            revert("accepted");
        } catch (bytes memory err) {
            assertTrue(bytes4(err) == ISupplierPulsePlus.WrongSigner.selector, "WrongSigner");
        }
    }

    // ------------------------------------------- real AirnodeHub responses (GLEIF)

    address constant GLEIF_AIRNODE = 0x26d83124541e89ef28B9A5FB012B4B5f4097C20c;

    bytes constant LEI_D_DATA = bytes('{"entity_status":"ACTIVE","registration_status":"ISSUED"}');
    bytes constant LEI_D_SIG =
        hex"89fe847673d03cbb3a3494be47bd0f6abab30fd5987ee967b955d11257ea79d55268dbb30fd9a3b60edb127a1f6121922516acae81f064d595920c731e65e41c1c";
    uint256 constant LEI_D_TS = 1793376460;

    /// One-milestone GLEIF order (approved) on a contract that trusts the real GLEIF Airnode. The responses below
    /// are real signed getLegalEntity records (30 Oct 17:07 CET, paid via x402; api3/fixtures/ on emre/plus-data).
    function _gleifOrder(string memory lei, uint256 ts) internal returns (SupplierPulsePlus live, uint256 id) {
        vm.warp(ts + 10);
        live = new SupplierPulsePlus(vm.addr(CH_KEY), GLEIF_AIRNODE, MAX_AGE, GAP, GRACE);
        id = live.createOrder{value: 1 ether}(1, lei, supplier, 0, _amounts(1), _dues(1, ts, 0), TTL, 0x08);
        live.approveMilestone(id, 0);
    }

    function test_realGleifActiveIssuedIsPaid() public {
        (SupplierPulsePlus live, uint256 id) = _gleifOrder("391200JI69LS8L648F30", LEI_D_TS);
        bytes32 req = live.requestHashFor(1, "391200JI69LS8L648F30");
        assertTrue(req == 0x428725c3fad90b9f3709a91b72530344bad9ceb87e33304d9eeb0d7290585e79, "signed request hash");
        assertEq(live.checkAndRelease(id, req, LEI_D_TS, LEI_D_DATA, LEI_D_SIG), 0, "paid");
        assertEq(supplier.balance, 1 ether, "supplier paid");
    }

    function test_realGleifLapsedIsHeld() public {
        (SupplierPulsePlus live, uint256 id) = _gleifOrder("52990092KBQJF8QBGJ50", 1793376461);
        uint8 o = live.checkAndRelease(
            id,
            live.requestHashFor(1, "52990092KBQJF8QBGJ50"),
            1793376461,
            bytes('{"entity_status":"ACTIVE","registration_status":"LAPSED"}'),
            hex"d2ad3f67f559968249345a9b3827ecf230c5f40525156e3c0b86d91b5f6c7d73212daa971c11d55c2319ce121bc4458bb5af9c77ac09bd09b36092a0c3d8ea8d1c"
        );
        assertEq(o, 3, "held");
        (,, uint8 f,,,) = live.orderSchedule(id);
        assertEq(f, 0x08, "LEI renewal overdue");
        assertEq(supplier.balance, 0, "not paid");
    }

    function test_realGleifResponseTooOld() public {
        // the genuine record, untouched, submitted after maxAge (tamper case b with a real input)
        (SupplierPulsePlus live, uint256 id) = _gleifOrder("391200JI69LS8L648F30", LEI_D_TS);
        bytes32 req = live.requestHashFor(1, "391200JI69LS8L648F30");
        vm.warp(LEI_D_TS + MAX_AGE + 1);
        vm.expectRevert(
            abi.encodeWithSelector(ISupplierPulsePlus.StaleResponse.selector, LEI_D_TS, LEI_D_TS + MAX_AGE + 1)
        );
        live.submitEvidence(id, req, LEI_D_TS, LEI_D_DATA, LEI_D_SIG);
    }

    function test_realGleifResponseForAnotherLei() public {
        // the genuine ISSUED record for one LEI, submitted to an order on another LEI (tamper case c)
        (SupplierPulsePlus live, uint256 id) = _gleifOrder("52990092KBQJF8QBGJ50", LEI_D_TS);
        bytes32 req = live.requestHashFor(1, "391200JI69LS8L648F30");
        bytes32 expected = live.requestHashFor(1, "52990092KBQJF8QBGJ50");
        vm.expectRevert(abi.encodeWithSelector(ISupplierPulsePlus.WrongRequest.selector, req, expected));
        live.submitEvidence(id, req, LEI_D_TS, LEI_D_DATA, LEI_D_SIG);
    }

    // ------------------------------------------------------------------ admin

    function test_adminOnly() public {
        vm.prank(stranger);
        vm.expectRevert(ISupplierPulsePlus.NotAuthorized.selector);
        pulse.setAirnode(0, stranger);
        vm.prank(stranger);
        vm.expectRevert(ISupplierPulsePlus.NotAuthorized.selector);
        pulse.setMaxAge(1);
        vm.expectRevert(ISupplierPulsePlus.BadSource.selector);
        pulse.setAirnode(2, stranger);
    }

    function test_adminUpdates() public {
        vmE.expectEmit(false, false, false, true, address(pulse));
        emit ISupplierPulsePlus.ConfigUpdated(1, stranger, MAX_AGE);
        pulse.setAirnode(1, stranger);
        assertTrue(pulse.airnodeOf(1) == stranger, "airnode set");
        pulse.setMaxAge(600);
        assertEq(pulse.maxAge(), 600, "maxAge set");
    }

    // ------------------------------------------------------------- JsonFields

    function test_parseBool() public {
        JsonFieldsHarness h = new JsonFieldsHarness();
        assertTrue(h.parseBool('{"a":true}', '"a":'), "true");
        assertTrue(!h.parseBool('{"a": false}', '"a":'), "false with space");
        vm.expectRevert(JsonFields.NoBool.selector);
        h.parseBool('{"a":"true"}', '"a":');
        vm.expectRevert(JsonFields.NoBool.selector);
        h.parseBool('{"a":null}', '"a":');
        vm.expectRevert(JsonFields.KeyNotFound.selector);
        h.parseBool('{"b":true}', '"a":');
    }

    function test_statusKeyDoesNotMatchEntityStatus() public {
        // "status": must never match inside "entity_status": (the leading quote is part of the key)
        uint256 id = _order(0, CH_ID, 1, 0);
        bytes memory data = bytes('{"entity_status":"active"}');
        vm.expectRevert(bytes4(keccak256("KeyNotFound()")));
        pulse.submitEvidence(id, CH_REQ, NOW, data, _sign(CH_KEY, CH_REQ, NOW, data));
    }
}
