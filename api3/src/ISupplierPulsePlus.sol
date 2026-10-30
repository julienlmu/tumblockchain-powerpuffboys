// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// SupplierPulse+ interface, frozen in docs/SUPPLIERPULSE_PLUS.md §4.4 (v1.1).
/// Enums travel as uint8:
///   source  0 CompaniesHouse, 1 Gleif
///   state   0 Active, 1 Held, 2 Closed
///   outcome 0 Paid, 1 AwaitingApproval, 2 NotDue, 3 Held
///   tier    0 Standard, 1 Trusted, 2 Premium
/// rules / failedRules bits: 0x01 reserved (unused), 0x02 accounts current (CH),
///   0x04 confirmation statement current (CH), 0x08 LEI registration issued (GLEIF),
///   0x80 (failedRules only) base status check failed.
interface ISupplierPulsePlus {
    event OrderCreated(
        uint256 indexed orderId,
        address indexed buyer,
        bytes32 indexed supplierKey,
        address supplier,
        uint8 source,
        string supplierId,
        bytes32 requestHash,
        bytes32 orderRef,
        uint256 total,
        uint8 rules
    );
    event MilestoneApproved(uint256 indexed orderId, uint256 milestone);
    event EvidenceAccepted(
        uint256 indexed orderId,
        bytes32 indexed supplierKey,
        bool clean,
        uint8 failedRules,
        uint256 timestamp,
        bytes32 digest,
        address submitter,
        bytes data
    );
    event PermitIssued(uint256 indexed orderId, uint256 milestone, uint256 amount, uint64 validUntil, bytes32 evidence);
    event MilestonePaid(uint256 indexed orderId, uint256 milestone, address supplier, uint256 amount, bytes32 evidence);
    event OrderHeld(uint256 indexed orderId, uint8 failedRules, uint256 remaining, uint64 autoRefundAt);
    event OrderRefunded(uint256 indexed orderId, address buyer, uint256 amount, address triggeredBy, bool noDataExit);
    event TierChanged(bytes32 indexed supplierKey, uint8 oldTier, uint8 newTier, uint32 cleanStreak);
    event ConfigUpdated(uint8 source, address airnode, uint256 maxAgeSeconds);

    error WrongSigner(address recovered);
    error WrongRequest(bytes32 got, bytes32 expected);
    error StaleResponse(uint256 timestamp, uint256 nowTs);
    error FutureResponse(uint256 timestamp, uint256 nowTs);
    error Replayed(bytes32 digest);
    error NotNewer(uint256 timestamp, uint256 lastCheck);
    error NoValidPermit(uint256 milestone);
    error PermitExpired(uint256 validUntil, uint256 nowTs);
    error NotApproved(uint256 milestone);
    error NotDue(uint256 dueDate, uint256 nowTs);
    error NotActive(uint8 state);
    error NotRefundable();
    error RefundNotYet(uint256 refundableAt);
    error SupplierFailed(uint256 failedAt);
    error NoNewerFailure();
    error BadOrder();
    error BadSource();
    error BadSupplierId();
    error BadRules();
    error NotAuthorized();
    error TransferFailed();

    // ---- buyer
    function createOrder(
        uint8 source,
        string calldata supplierId,
        address payable supplier,
        bytes32 orderRef,
        uint256[] calldata amounts,
        uint64[] calldata dueDates,
        uint64 permitTtl,
        uint8 rules
    ) external payable returns (uint256 orderId);
    function approveMilestone(uint256 orderId, uint256 milestone) external;
    /// Held: the buyer any time, anyone from heldAt + refundGrace. Active (no-data exit): anyone, once the next
    /// milestone is approved, has no valid permit, and refundGrace has passed since max(due date, first approval).
    /// The money always goes to the buyer.
    function refundRemaining(uint256 orderId) external;

    // ---- anyone (agent, judges)
    function submitEvidence(
        uint256 orderId,
        bytes32 requestHash,
        uint256 timestamp,
        bytes calldata data,
        bytes calldata signature
    ) external returns (bool clean);
    function release(uint256 orderId) external;
    function checkAndRelease(
        uint256 orderId,
        bytes32 requestHash,
        uint256 timestamp,
        bytes calldata data,
        bytes calldata signature
    ) external returns (uint8 outcome);
    /// Hold this order because its supplier's register status failed on another order (no new evidence needed).
    function applySupplierFailure(uint256 orderId) external;

    // ---- views
    function requestHashFor(uint8 source, string calldata supplierId) external pure returns (bytes32);
    function supplierKeyOf(uint8 source, string calldata supplierId) external pure returns (bytes32);
    function ordersLength() external view returns (uint256);
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
        );
    function orderMilestones(uint256 orderId)
        external
        view
        returns (uint256[] memory amounts, uint64[] memory dueDates, bool[] memory approved);
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
        );
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
        );
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
        );
    function airnodeOf(uint8 source) external view returns (address);
    function maxAge() external view returns (uint256);
    function tierCountGap() external view returns (uint64);
    function refundGrace() external view returns (uint64);
    function usedDigests(bytes32 digest) external view returns (bool);
    function admin() external view returns (address);

    // ---- admin
    function setAirnode(uint8 source, address airnode) external;
    function setMaxAge(uint256 newMaxAge) external;
}
