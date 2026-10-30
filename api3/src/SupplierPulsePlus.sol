// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ISupplierPulsePlus} from "./ISupplierPulsePlus.sol";
import {IOrderDocuments} from "./IOrderDocuments.sol";
import {AirnodeVerifier} from "./AirnodeVerifier.sol";
import {PriceParser} from "./PriceParser.sol";
import {JsonFields} from "./JsonFields.sol";

/// @title SupplierPulsePlus
/// @notice Milestone payments to a supplier that need fresh signed registry evidence before every payment.
/// Two registries: Companies House (UK company number) and GLEIF (LEI). The buyer picks rules per order
/// (accounts current, confirmation statement current, LEI issued).
/// Clean evidence issues a permit for exactly the next milestone; anything else holds the remaining
/// balance for the buyer. Every newer record updates the supplier's verification history (tier), which only
/// tells the agent how often to re-check; permits are never extended. A failed register status stops payments
/// on every order of that supplier, and data that never arrives lets the buyer take the money back.
/// Behaviour is specified in docs/SUPPLIERPULSE_PLUS.md §4.5 (v1.1). Order documents (salted hash, locked or
/// amendable with both signatures) are described in IOrderDocuments.
contract SupplierPulsePlus is ISupplierPulsePlus, IOrderDocuments {
    uint8 internal constant SOURCE_CH = 0;
    uint8 internal constant SOURCE_GLEIF = 1;

    uint8 internal constant STATE_ACTIVE = 0;
    uint8 internal constant STATE_HELD = 1;
    uint8 internal constant STATE_CLOSED = 2;

    uint8 internal constant OUTCOME_PAID = 0;
    uint8 internal constant OUTCOME_AWAITING_APPROVAL = 1;
    uint8 internal constant OUTCOME_NOT_DUE = 2;
    uint8 internal constant OUTCOME_HELD = 3;

    uint8 public constant RULE_ACCOUNTS_CURRENT = 0x02;
    uint8 public constant RULE_CONFIRMATION_CURRENT = 0x04;
    uint8 public constant RULE_LEI_ISSUED = 0x08;
    uint8 public constant BASE_FAILED = 0x80;
    uint8 internal constant CH_RULES = 0x06; // 0x01 is reserved since v1.1
    uint8 internal constant GLEIF_RULES = 0x08;

    uint8 internal constant DOC_LOCKED = 0;
    uint8 internal constant DOC_AMENDABLE = 1;
    // secp256k1n / 2, rejects malleable (high-s) signatures
    uint256 internal constant HALF_N = 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0;

    uint256 public constant MAX_FUTURE_SKEW = 60;
    uint32 public constant TRUSTED_STREAK = 3;
    uint32 public constant PREMIUM_STREAK = 6;

    // request templates (§4.2): prefix + supplier id + suffix
    bytes internal constant CH_PREFIX = '["getCompanyProfile",[["company_number","';
    bytes internal constant CH_SUFFIX =
        '"]],[["accounts_overdue","/accounts/next_accounts/overdue"],["confirmation_overdue","/confirmation_statement/overdue"],["status","/company_status"]]]';
    bytes internal constant GLEIF_PREFIX = '["getLegalEntity",[["lei","';
    bytes internal constant GLEIF_SUFFIX =
        '"]],[["entity_status","/data/attributes/entity/status"],["registration_status","/data/attributes/registration/status"]]]';

    struct Permit {
        uint64 validUntil; // 0: no permit
        uint32 milestone;
        uint64 evidenceAt; // timestamp of that response
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
        uint64[] approvedAt; // first approval of each milestone; the no-data exit counts from max(due, approvedAt)
        Permit permit;
    }

    struct SupplierRecord {
        uint32 cleanStreak;
        uint32 checks;
        uint32 failures;
        uint64 lastCountedAt;
        uint64 lastCheckAt;
        uint64 lastBaseFailureAt; // newest record whose register status failed; stops all orders of the supplier
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
    mapping(uint256 => uint8) internal docModes;
    mapping(uint256 => bytes32[]) internal docAmendments; // versions 1, 2, … (version 0 is orderRef)

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
    ) public payable returns (uint256 orderId) {
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
        o.approvedAt = new uint64[](amounts.length);
        _emitCreated(orderId, o, total);
    }

    /// Same as createOrder, but the document (docHash = orderRef) can later be amended by buyer and supplier together
    function createAmendableOrder(
        uint8 source,
        string calldata supplierId,
        address payable supplier,
        bytes32 docHash,
        uint256[] calldata amounts,
        uint64[] calldata dueDates,
        uint64 permitTtl,
        uint8 rules
    ) external payable returns (uint256 orderId) {
        if (docHash == bytes32(0)) revert BadDocumentHash();
        orderId = createOrder(source, supplierId, supplier, docHash, amounts, dueDates, permitTtl, rules);
        docModes[orderId] = DOC_AMENDABLE;
    }

    function approveMilestone(uint256 orderId, uint256 milestone) external {
        Order storage o = _order(orderId);
        if (msg.sender != o.buyer) revert NotAuthorized();
        if (milestone >= o.amounts.length) revert BadOrder();
        if (!o.approved[milestone]) o.approvedAt[milestone] = uint64(block.timestamp);
        o.approved[milestone] = true;
        emit MilestoneApproved(orderId, milestone);
    }

    /// @notice Held: the buyer any time, anyone from heldAt + refundGrace. Active (no-data exit): anyone, once the
    /// next milestone is approved, has no valid permit, and refundGrace has passed since its due date and its approval
    /// (whichever is later), so a late approval still gives the supplier the full grace. The money always goes to the buyer.
    function refundRemaining(uint256 orderId) external {
        Order storage o = _order(orderId);
        bool noDataExit;
        if (o.state == STATE_HELD) {
            uint256 at = uint256(o.heldAt) + refundGrace;
            if (msg.sender != o.buyer && block.timestamp < at) revert RefundNotYet(at);
        } else if (o.state == STATE_ACTIVE) {
            uint256 m = o.paidCount;
            if (!o.approved[m]) revert NotApproved(m);
            if (_permitValid(o)) revert NotRefundable();
            uint256 at = _noDataExitAt(o, m);
            if (block.timestamp < at) revert RefundNotYet(at);
            noDataExit = true;
        } else {
            revert NotRefundable();
        }
        uint256 amount = _remaining(o);
        o.state = STATE_CLOSED;
        o.permit = Permit(0, 0, 0, bytes32(0));
        emit OrderRefunded(orderId, o.buyer, amount, msg.sender, noDataExit);
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
        uint64 failedAt = suppliers[o.supplierKey].lastBaseFailureAt;
        if (p.evidenceAt <= failedAt) revert SupplierFailed(failedAt); // a newer failure on any order stops this payment

        uint256 amount = o.amounts[m];
        o.permit = Permit(0, 0, 0, bytes32(0)); // used up: the next milestone needs new evidence
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

    /// @notice Hold this order because its supplier's register status failed on another order. The failure is
    /// already verified on chain, so no new (paid) evidence is needed.
    function applySupplierFailure(uint256 orderId) external {
        Order storage o = _order(orderId);
        if (o.state != STATE_ACTIVE) revert NotActive(o.state);
        if (suppliers[o.supplierKey].lastBaseFailureAt <= o.lastCheck) revert NoNewerFailure();
        o.lastFailedRules = BASE_FAILED;
        _hold(orderId, o, BASE_FAILED);
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
        permitValid = _permitValid(o);
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
        if (o.state == STATE_HELD) {
            autoRefundAt = o.heldAt + refundGrace;
        } else if (o.state == STATE_ACTIVE && o.approved[o.paidCount] && !_permitValid(o)) {
            autoRefundAt = _noDataExitAt(o, o.paidCount); // the no-data exit
        }
        tier = suppliers[o.supplierKey].tier;
    }

    // ---------------------------------------------------------------- order documents

    function amendDocument(uint256 orderId, bytes32 newHash, bytes calldata buyerSig, bytes calldata supplierSig)
        external
    {
        Order storage o = _order(orderId);
        if (docModes[orderId] != DOC_AMENDABLE) revert DocumentLocked(orderId);
        if (o.state == STATE_CLOSED) revert NotActive(o.state);
        if (newHash == bytes32(0)) revert BadDocumentHash();
        bytes32 d = amendmentDigest(orderId, newHash);
        address b = _recover(d, buyerSig);
        if (b != o.buyer) revert BadAmendSignature(b, o.buyer);
        address s = _recover(d, supplierSig);
        if (s != o.supplier) revert BadAmendSignature(s, o.supplier);
        (, bytes32 previous, uint256 version) = documentOf(orderId);
        docAmendments[orderId].push(newHash);
        emit DocumentAmended(orderId, version + 1, previous, newHash);
    }

    function amendmentDigest(uint256 orderId, bytes32 newHash) public view returns (bytes32) {
        (, bytes32 current, uint256 version) = documentOf(orderId);
        return keccak256(
            abi.encode(
                "SupplierPulsePlus.amendDocument", block.chainid, address(this), orderId, version + 1, current, newHash
            )
        );
    }

    function documentOf(uint256 orderId) public view returns (uint8 mode, bytes32 current, uint256 version) {
        Order storage o = _order(orderId);
        bytes32[] storage a = docAmendments[orderId];
        version = a.length;
        current = version == 0 ? o.orderRef : a[version - 1];
        mode = docModes[orderId];
    }

    function documentHistory(uint256 orderId) external view returns (bytes32[] memory h) {
        Order storage o = _order(orderId);
        bytes32[] storage a = docAmendments[orderId];
        h = new bytes32[](a.length + 1);
        h[0] = o.orderRef;
        for (uint256 i = 0; i < a.length; i++) {
            h[i + 1] = a[i];
        }
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
            uint64 lastBaseFailureAt,
            uint8 tier
        )
    {
        SupplierRecord storage r = suppliers[supplierKey];
        return (r.cleanStreak, r.checks, r.failures, r.lastCountedAt, r.lastCheckAt, r.lastBaseFailureAt, r.tier);
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
        uint64 failedAt = suppliers[o.supplierKey].lastBaseFailureAt;
        if (clean && timestamp <= failedAt) revert SupplierFailed(failedAt); // older than a known failure

        usedDigests[d] = true;
        o.lastCheck = timestamp;
        o.lastFailedRules = failedRules;
        _updateSupplier(o.supplierKey, failedRules & BASE_FAILED == 0, timestamp);
        _emitAccepted(orderId, o, d, timestamp, data);

        if (!clean) {
            _hold(orderId, o, failedRules);
            return false;
        }

        // counted from the evidence time, not from when it was submitted; the tier never extends it
        uint64 validUntil = uint64(timestamp + o.permitTtl);
        o.permit = Permit(validUntil, o.paidCount, uint64(timestamp), d);
        emit PermitIssued(orderId, o.paidCount, o.amounts[o.paidCount], validUntil, d);
    }

    function _hold(uint256 orderId, Order storage o, uint8 failedRules) internal {
        o.state = STATE_HELD;
        o.heldAt = uint64(block.timestamp);
        o.permit = Permit(0, 0, 0, bytes32(0));
        emit OrderHeld(orderId, failedRules, _remaining(o), o.heldAt + refundGrace);
    }

    function _permitValid(Order storage o) internal view returns (bool) {
        Permit storage p = o.permit;
        return o.state == STATE_ACTIVE && p.validUntil != 0 && p.milestone == o.paidCount
            && block.timestamp <= p.validUntil;
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

    /// @dev Verification history (§2.4): only the base status counts, and only a record newer than anything seen
    /// for this supplier moves it, so the history never goes backwards.
    function _updateSupplier(bytes32 key, bool baseOk, uint256 timestamp) internal {
        SupplierRecord storage r = suppliers[key];
        if (timestamp <= r.lastCheckAt) return;
        r.checks++;
        r.lastCheckAt = uint64(timestamp);
        if (baseOk) {
            if (r.lastCountedAt == 0 || timestamp >= uint256(r.lastCountedAt) + tierCountGap) {
                r.cleanStreak++;
                r.lastCountedAt = uint64(timestamp);
            }
        } else {
            r.failures++;
            r.cleanStreak = 0;
            r.lastBaseFailureAt = uint64(timestamp);
        }
        uint8 old = r.tier;
        uint8 tier = r.cleanStreak >= PREMIUM_STREAK ? 2 : r.cleanStreak >= TRUSTED_STREAK ? 1 : 0;
        if (tier != old) {
            r.tier = tier;
            emit TierChanged(key, old, tier, r.cleanStreak);
        }
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
    ) internal view returns (uint256 total) {
        // permitTtl >= maxAge: a permit from any record the contract accepts is still valid when it is issued
        if (supplier == address(0) || amounts.length == 0 || amounts.length != dueDates.length || permitTtl == 0 || permitTtl < maxAge) {
            revert BadOrder();
        }
        for (uint256 i = 0; i < amounts.length; i++) {
            if (amounts[i] == 0 || (i > 0 && dueDates[i] < dueDates[i - 1])) revert BadOrder();
            total += amounts[i];
        }
    }

    function _noDataExitAt(Order storage o, uint256 m) internal view returns (uint64) {
        uint64 due = o.dueDates[m];
        uint64 approvedAt = o.approvedAt[m];
        return (approvedAt > due ? approvedAt : due) + refundGrace;
    }

    /// EIP-191 personal_sign recovery with the same checks as AirnodeVerifier
    function _recover(bytes32 d, bytes calldata sig) internal pure returns (address signer) {
        if (sig.length != 65) revert AirnodeVerifier.InvalidSignatureLength();
        bytes32 r = bytes32(sig[0:32]);
        bytes32 s = bytes32(sig[32:64]);
        uint8 v = uint8(sig[64]);
        if (v < 27) v += 27;
        if (v != 27 && v != 28) revert AirnodeVerifier.InvalidSignatureV();
        if (uint256(s) > HALF_N) revert AirnodeVerifier.InvalidSignatureS();
        signer = ecrecover(AirnodeVerifier.ethSignedHash(d), v, r, s);
        if (signer == address(0)) revert AirnodeVerifier.InvalidSigner();
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
