// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ISupplierPulsePlus} from "./ISupplierPulsePlus.sol";
import {AirnodeVerifier} from "./AirnodeVerifier.sol";
import {PriceParser} from "./PriceParser.sol";
import {JsonFields} from "./JsonFields.sol";

/// @title SupplierPulsePlus
/// @notice Milestone payments to a supplier that need fresh signed registry evidence before every payment.
/// Two registries: Companies House (UK company number) and GLEIF (LEI). The buyer picks rules per order
/// (no insolvency history, accounts current, confirmation statement current, LEI issued).
/// Clean evidence issues a permit for exactly the next milestone; anything else holds the remaining
/// balance for the buyer. Every accepted record also updates the supplier's trust tier, which makes
/// permits last longer (fewer paid checks for suppliers with a clean track record).
/// Behaviour is specified in docs/SUPPLIERPULSE_PLUS.md §4.5.
contract SupplierPulsePlus is ISupplierPulsePlus {
    uint8 internal constant SOURCE_CH = 0;
    uint8 internal constant SOURCE_GLEIF = 1;

    uint8 internal constant STATE_ACTIVE = 0;
    uint8 internal constant STATE_HELD = 1;
    uint8 internal constant STATE_CLOSED = 2;

    uint8 internal constant OUTCOME_PAID = 0;
    uint8 internal constant OUTCOME_AWAITING_APPROVAL = 1;
    uint8 internal constant OUTCOME_NOT_DUE = 2;
    uint8 internal constant OUTCOME_HELD = 3;

    uint8 public constant RULE_NO_INSOLVENCY = 0x01;
    uint8 public constant RULE_ACCOUNTS_CURRENT = 0x02;
    uint8 public constant RULE_CONFIRMATION_CURRENT = 0x04;
    uint8 public constant RULE_LEI_ISSUED = 0x08;
    uint8 public constant BASE_FAILED = 0x80;
    uint8 internal constant CH_RULES = 0x07;
    uint8 internal constant GLEIF_RULES = 0x08;

    uint256 public constant MAX_FUTURE_SKEW = 60;
    uint32 public constant TRUSTED_STREAK = 3;
    uint32 public constant PREMIUM_STREAK = 6;

    // request templates (§4.2): prefix + supplier id + suffix
    bytes internal constant CH_PREFIX = '["getCompanyProfile",[["company_number","';
    bytes internal constant CH_SUFFIX =
        '"]],[["accounts_overdue","/accounts/overdue"],["confirmation_overdue","/confirmation_statement/overdue"],["insolvency","/has_insolvency_history"],["status","/company_status"]]]';
    bytes internal constant GLEIF_PREFIX = '["getLegalEntity",[["lei","';
    bytes internal constant GLEIF_SUFFIX =
        '"]],[["entity_status","/data/attributes/entity/status"],["registration_status","/data/attributes/registration/status"]]]';

    struct Permit {
        uint64 validUntil; // 0: no permit
        uint32 milestone;
        bytes32 evidence; // digest of the signed response it is based on
    }

    struct Order {
        address buyer;
        address payable supplier; // fixed at creation
        uint8 source;
        uint8 rules;
        uint8 state;
        uint8 lastFailedRules;
        uint32 paidCount; // milestones paid so far (= index of the next milestone)
        uint64 permitTtl;
        uint64 heldAt;
        bytes32 supplierKey;
        bytes32 requestHash;
        bytes32 orderRef;
        uint256 paid;
        uint256 lastCheck; // Airnode timestamp of the last accepted evidence
        string supplierId;
        uint256[] amounts;
        uint64[] dueDates;
        bool[] approved;
        Permit permit;
    }

    struct SupplierRecord {
        uint32 cleanStreak;
        uint32 checks;
        uint32 failures;
        uint64 lastCountedAt;
        uint64 lastCheckAt;
        uint8 tier;
    }

    address public admin;
    uint256 public maxAge;
    uint64 public tierCountGap;
    uint64 public refundGrace;
    mapping(bytes32 => bool) public usedDigests;

    address[2] internal airnodes;
    Order[] internal orders;
    mapping(bytes32 => SupplierRecord) internal suppliers;

    constructor(address chAirnode, address gleifAirnode, uint256 _maxAge, uint64 _tierCountGap, uint64 _refundGrace) {
        admin = msg.sender;
        airnodes[SOURCE_CH] = chAirnode;
        airnodes[SOURCE_GLEIF] = gleifAirnode;
        maxAge = _maxAge;
        tierCountGap = _tierCountGap;
        refundGrace = _refundGrace;
        emit ConfigUpdated(SOURCE_CH, chAirnode, _maxAge);
        emit ConfigUpdated(SOURCE_GLEIF, gleifAirnode, _maxAge);
    }

    // ---------------------------------------------------------------- buyer

    function createOrder(
        uint8 source,
        string calldata supplierId,
        address payable supplier,
        bytes32 orderRef,
        uint256[] calldata amounts,
        uint64[] calldata dueDates,
        uint64 permitTtl,
        uint8 rules
    ) external payable returns (uint256 orderId) {
        bytes32 requestHash = requestHashFor(source, supplierId); // BadSource, BadSupplierId
        if (rules & ~(source == SOURCE_CH ? CH_RULES : GLEIF_RULES) != 0) revert BadRules();
        uint256 total = _checkSchedule(supplier, amounts, dueDates, permitTtl);
        if (msg.value != total) revert BadOrder();

        orderId = orders.length;
        Order storage o = orders.push();
        o.buyer = msg.sender;
        o.supplier = supplier;
        o.source = source;
        o.rules = rules;
        o.permitTtl = permitTtl;
        o.supplierKey = supplierKeyOf(source, supplierId);
        o.requestHash = requestHash;
        o.orderRef = orderRef;
        o.supplierId = supplierId;
        o.amounts = amounts;
        o.dueDates = dueDates;
        o.approved = new bool[](amounts.length);
        _emitCreated(orderId, o, total);
    }

    function approveMilestone(uint256 orderId, uint256 milestone) external {
        Order storage o = _order(orderId);
        if (msg.sender != o.buyer) revert NotAuthorized();
        if (milestone >= o.amounts.length) revert BadOrder();
        o.approved[milestone] = true;
        emit MilestoneApproved(orderId, milestone);
    }

    /// @notice After a hold: the buyer any time, anyone from autoRefundAt on. The money always goes to the buyer.
    function refundRemaining(uint256 orderId) external {
        Order storage o = _order(orderId);
        if (o.state != STATE_HELD) revert NotHeld();
        uint256 autoRefundAt = uint256(o.heldAt) + refundGrace;
        if (msg.sender != o.buyer && block.timestamp < autoRefundAt) revert RefundNotYet(autoRefundAt);
        uint256 amount = _remaining(o);
        o.state = STATE_CLOSED;
        emit OrderRefunded(orderId, o.buyer, amount, msg.sender);
        (bool ok,) = payable(o.buyer).call{value: amount}("");
        if (!ok) revert TransferFailed();
    }

    // ------------------------------------------------------ anyone (agent, judges)

    /// @notice Verify a signed registry record for this order. Clean issues a permit for the next
    /// milestone; anything else holds the order. Reverts on any verification failure.
    function submitEvidence(
        uint256 orderId,
        bytes32 requestHash,
        uint256 timestamp,
        bytes calldata data,
        bytes calldata signature
    ) public returns (bool clean) {
        Order storage o = _order(orderId);
        bytes32 d = _verify(o, requestHash, timestamp, data, signature);
        return _apply(orderId, o, d, timestamp, data);
    }

    /// @notice Pay the next milestone with the current permit.
    function release(uint256 orderId) public {
        Order storage o = _order(orderId);
        if (o.state != STATE_ACTIVE) revert NotActive(o.state);
        uint256 m = o.paidCount;
        Permit memory p = o.permit;
        if (p.validUntil == 0 || p.milestone != m) revert NoValidPermit(m);
        if (block.timestamp > p.validUntil) revert PermitExpired(p.validUntil, block.timestamp);
        if (!o.approved[m]) revert NotApproved(m);
        if (block.timestamp < o.dueDates[m]) revert NotDue(o.dueDates[m], block.timestamp);

        uint256 amount = o.amounts[m];
        o.permit = Permit(0, 0, bytes32(0)); // used up: the next milestone needs new evidence
        o.paidCount = uint32(m + 1);
        o.paid += amount;
        if (o.paidCount == o.amounts.length) o.state = STATE_CLOSED;
        emit MilestonePaid(orderId, m, o.supplier, amount, p.evidence);
        (bool ok,) = o.supplier.call{value: amount}("");
        if (!ok) revert TransferFailed();
    }

    /// @notice One call for the agent. Reverts only on verification failures.
    function checkAndRelease(
        uint256 orderId,
        bytes32 requestHash,
        uint256 timestamp,
        bytes calldata data,
        bytes calldata signature
    ) external returns (uint8 outcome) {
        if (!submitEvidence(orderId, requestHash, timestamp, data, signature)) return OUTCOME_HELD;
        Order storage o = orders[orderId];
        uint256 m = o.paidCount;
        if (!o.approved[m]) return OUTCOME_AWAITING_APPROVAL;
        if (block.timestamp < o.dueDates[m]) return OUTCOME_NOT_DUE;
        release(orderId);
        return OUTCOME_PAID;
    }

    // ---------------------------------------------------------------- views

    /// @notice The only Airnode request an order accepts, built from the supplier id so nobody can bind an
    /// order to another company or query: keccak256(JSON.stringify([operation, params, projection])).
    function requestHashFor(uint8 source, string calldata supplierId) public pure returns (bytes32) {
        _checkId(source, bytes(supplierId));
        if (source == SOURCE_CH) return keccak256(abi.encodePacked(CH_PREFIX, supplierId, CH_SUFFIX));
        return keccak256(abi.encodePacked(GLEIF_PREFIX, supplierId, GLEIF_SUFFIX));
    }

    function supplierKeyOf(uint8 source, string calldata supplierId) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(source, bytes(supplierId)));
    }

    function ordersLength() external view returns (uint256) {
        return orders.length;
    }

    function orderInfo(uint256 orderId)
        external
        view
        returns (
            address buyer,
            address supplier,
            uint8 source,
            string memory supplierId,
            bytes32 requestHash,
            bytes32 orderRef,
            uint64 permitTtl,
            uint8 rules
        )
    {
        Order storage o = _order(orderId);
        return (o.buyer, o.supplier, o.source, o.supplierId, o.requestHash, o.orderRef, o.permitTtl, o.rules);
    }

    function orderMilestones(uint256 orderId)
        external
        view
        returns (uint256[] memory amounts, uint64[] memory dueDates, bool[] memory approved)
    {
        Order storage o = _order(orderId);
        return (o.amounts, o.dueDates, o.approved);
    }

    function orderStatus(uint256 orderId)
        external
        view
        returns (
            uint8 state,
            uint256 paid,
            uint256 remaining,
            uint256 nextMilestone,
            uint256 milestones,
            uint64 permitValidUntil,
            bool permitValid,
            uint256 lastCheck
        )
    {
        Order storage o = _order(orderId);
        Permit memory p = o.permit;
        state = o.state;
        paid = o.paid;
        remaining = _remaining(o);
        nextMilestone = o.paidCount;
        milestones = o.amounts.length;
        permitValidUntil = p.validUntil;
        permitValid = o.state == STATE_ACTIVE && p.validUntil != 0 && p.milestone == o.paidCount
            && block.timestamp <= p.validUntil;
        lastCheck = o.lastCheck;
    }

    function orderSchedule(uint256 orderId)
        external
        view
        returns (
            uint64 nextDueDate,
            bool nextApproved,
            uint8 lastFailedRules,
            uint64 heldAt,
            uint64 autoRefundAt,
            uint8 tier
        )
    {
        Order storage o = _order(orderId);
        if (o.state != STATE_CLOSED) {
            nextDueDate = o.dueDates[o.paidCount];
            nextApproved = o.approved[o.paidCount];
        }
        lastFailedRules = o.lastFailedRules;
        heldAt = o.heldAt;
        if (o.state == STATE_HELD) autoRefundAt = o.heldAt + refundGrace;
        tier = suppliers[o.supplierKey].tier;
    }

    function supplierRecord(bytes32 supplierKey)
        external
        view
        returns (
            uint32 cleanStreak,
            uint32 checks,
            uint32 failures,
            uint64 lastCountedAt,
            uint64 lastCheckAt,
            uint8 tier
        )
    {
        SupplierRecord storage r = suppliers[supplierKey];
        return (r.cleanStreak, r.checks, r.failures, r.lastCountedAt, r.lastCheckAt, r.tier);
    }

    function effectivePermitTtl(uint256 orderId) external view returns (uint64) {
        Order storage o = _order(orderId);
        return uint64(uint256(o.permitTtl) * _multiplier(suppliers[o.supplierKey].tier));
    }

    function airnodeOf(uint8 source) public view returns (address) {
        if (source > SOURCE_GLEIF) revert BadSource();
        return airnodes[source];
    }

    // ---------------------------------------------------------------- admin

    function setAirnode(uint8 source, address airnode) external {
        if (msg.sender != admin) revert NotAuthorized();
        if (source > SOURCE_GLEIF) revert BadSource();
        airnodes[source] = airnode;
        emit ConfigUpdated(source, airnode, maxAge);
    }

    function setMaxAge(uint256 newMaxAge) external {
        if (msg.sender != admin) revert NotAuthorized();
        maxAge = newMaxAge;
        emit ConfigUpdated(SOURCE_CH, airnodes[SOURCE_CH], newMaxAge);
        emit ConfigUpdated(SOURCE_GLEIF, airnodes[SOURCE_GLEIF], newMaxAge);
    }

    // ------------------------------------------------------------- internal

    /// @dev §4.5 check order: it decides which error each tamper case produces.
    function _verify(
        Order storage o,
        bytes32 requestHash,
        uint256 timestamp,
        bytes calldata data,
        bytes calldata signature
    ) internal view returns (bytes32 d) {
        if (o.state != STATE_ACTIVE) revert NotActive(o.state);
        if (requestHash != o.requestHash) revert WrongRequest(requestHash, o.requestHash);
        if (timestamp > block.timestamp + MAX_FUTURE_SKEW) revert FutureResponse(timestamp, block.timestamp);
        if (block.timestamp > timestamp && block.timestamp - timestamp > maxAge) {
            revert StaleResponse(timestamp, block.timestamp);
        }
        d = AirnodeVerifier.digest(requestHash, timestamp, data);
        if (usedDigests[d]) revert Replayed(d);
        if (timestamp <= o.lastCheck) revert NotNewer(timestamp, o.lastCheck);
        address signer = AirnodeVerifier.recover(requestHash, timestamp, data, signature);
        if (signer != airnodes[o.source]) revert WrongSigner(signer);
    }

    /// @dev The effects of an accepted record (§4.5), split from submitEvidence to keep the stack small.
    function _apply(uint256 orderId, Order storage o, bytes32 d, uint256 timestamp, bytes calldata data)
        internal
        returns (bool clean)
    {
        uint8 failedRules = _failedRules(o.source, o.rules, data);
        clean = failedRules == 0;
        usedDigests[d] = true;
        o.lastCheck = timestamp;
        o.lastFailedRules = failedRules;
        uint8 tier = _updateSupplier(o.supplierKey, clean, timestamp);
        _emitAccepted(orderId, o, d, timestamp, data);

        if (!clean) {
            o.state = STATE_HELD;
            o.heldAt = uint64(block.timestamp);
            o.permit = Permit(0, 0, bytes32(0));
            emit OrderHeld(orderId, failedRules, _remaining(o), o.heldAt + refundGrace);
            return false;
        }

        // counted from the evidence time, not from when it was submitted
        uint64 validUntil = uint64(timestamp + uint256(o.permitTtl) * _multiplier(tier));
        o.permit = Permit(validUntil, o.paidCount, d);
        emit PermitIssued(orderId, o.paidCount, o.amounts[o.paidCount], validUntil, d);
    }

    function _emitAccepted(uint256 orderId, Order storage o, bytes32 d, uint256 timestamp, bytes calldata data)
        internal
    {
        uint8 failedRules = o.lastFailedRules;
        emit EvidenceAccepted(orderId, o.supplierKey, failedRules == 0, failedRules, timestamp, d, msg.sender, data);
    }

    /// @dev §4.3. Disabled rules are not parsed, so their fields may be missing.
    function _failedRules(uint8 source, uint8 rules, bytes calldata data) internal pure returns (uint8 failed) {
        if (source == SOURCE_CH) {
            if (keccak256(PriceParser.parseString(data, '"status":')) != keccak256("active")) failed |= BASE_FAILED;
            if (rules & RULE_NO_INSOLVENCY != 0 && JsonFields.parseBool(data, '"insolvency":')) {
                failed |= RULE_NO_INSOLVENCY;
            }
            if (rules & RULE_ACCOUNTS_CURRENT != 0 && JsonFields.parseBool(data, '"accounts_overdue":')) {
                failed |= RULE_ACCOUNTS_CURRENT;
            }
            if (rules & RULE_CONFIRMATION_CURRENT != 0 && JsonFields.parseBool(data, '"confirmation_overdue":')) {
                failed |= RULE_CONFIRMATION_CURRENT;
            }
        } else {
            if (keccak256(PriceParser.parseString(data, '"entity_status":')) != keccak256("ACTIVE")) {
                failed |= BASE_FAILED;
            }
            if (
                rules & RULE_LEI_ISSUED != 0
                    && keccak256(PriceParser.parseString(data, '"registration_status":')) != keccak256("ISSUED")
            ) failed |= RULE_LEI_ISSUED;
        }
    }

    /// @return tier the supplier's tier after this record
    function _updateSupplier(bytes32 key, bool clean, uint256 timestamp) internal returns (uint8 tier) {
        SupplierRecord storage r = suppliers[key];
        r.checks++;
        r.lastCheckAt = uint64(timestamp);
        if (clean) {
            if (r.lastCountedAt == 0 || timestamp >= uint256(r.lastCountedAt) + tierCountGap) {
                r.cleanStreak++;
                r.lastCountedAt = uint64(timestamp);
            }
        } else {
            r.failures++;
            r.cleanStreak = 0;
        }
        uint8 old = r.tier;
        tier = r.cleanStreak >= PREMIUM_STREAK ? 2 : r.cleanStreak >= TRUSTED_STREAK ? 1 : 0;
        if (tier != old) {
            r.tier = tier;
            emit TierChanged(key, old, tier, r.cleanStreak);
        }
    }

    function _multiplier(uint8 tier) internal pure returns (uint256) {
        return tier == 2 ? 4 : tier == 1 ? 2 : 1;
    }

    /// @dev Companies House: 1 to 10 of [0-9A-Z]. GLEIF: exactly 20 of [0-9A-Z]. Nothing to escape.
    function _checkId(uint8 source, bytes calldata id) internal pure {
        if (source > SOURCE_GLEIF) revert BadSource();
        if (source == SOURCE_CH ? (id.length == 0 || id.length > 10) : id.length != 20) revert BadSupplierId();
        for (uint256 i = 0; i < id.length; i++) {
            bytes1 c = id[i];
            if (!((c >= "0" && c <= "9") || (c >= "A" && c <= "Z"))) revert BadSupplierId();
        }
    }

    /// @return total sum of the milestone amounts
    function _checkSchedule(
        address supplier,
        uint256[] calldata amounts,
        uint64[] calldata dueDates,
        uint64 permitTtl
    ) internal pure returns (uint256 total) {
        if (supplier == address(0) || amounts.length == 0 || amounts.length != dueDates.length || permitTtl == 0) {
            revert BadOrder();
        }
        for (uint256 i = 0; i < amounts.length; i++) {
            if (amounts[i] == 0 || (i > 0 && dueDates[i] < dueDates[i - 1])) revert BadOrder();
            total += amounts[i];
        }
    }

    function _emitCreated(uint256 orderId, Order storage o, uint256 total) internal {
        emit OrderCreated(
            orderId, o.buyer, o.supplierKey, o.supplier, o.source, o.supplierId, o.requestHash, o.orderRef, total, o.rules
        );
    }

    function _order(uint256 orderId) internal view returns (Order storage) {
        if (orderId >= orders.length) revert BadOrder();
        return orders[orderId];
    }

    function _remaining(Order storage o) internal view returns (uint256 r) {
        if (o.state == STATE_CLOSED) return 0;
        for (uint256 i = o.paidCount; i < o.amounts.length; i++) {
            r += o.amounts[i];
        }
    }
}
