// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AirnodeVerifier} from "./AirnodeVerifier.sol";
import {PriceParser} from "./PriceParser.sol";

/// @title SupplierPulse
/// @notice Milestone payments to a supplier that need fresh registry evidence before every payment.
/// A buyer locks the full order amount. Each milestone is paid only when:
///   - the buyer approved that milestone, and
///   - a payment permit for exactly that milestone is still valid.
/// A permit is issued by submitting an AirnodeHub signed company profile (checked on-chain for:
/// trusted signer, this order's company request, freshness, no replay) whose status is "active".
/// A permit covers one order, one supplier wallet, one milestone and its amount, and expires after
/// `permitTtl`. It is used up by the payment, so the next milestone needs new evidence.
/// If the signed status is anything else, the rest of the order is held and the buyer can take it back.
contract SupplierPulse {
    enum State {
        Active,
        Held, // signed status was not "active": no more payments, buyer may refund
        Closed // fully paid or refunded
    }

    enum Outcome {
        Paid, // permit issued and milestone paid
        AwaitingApproval, // permit issued, buyer has not approved the milestone yet
        Held // status not active, order held
    }

    struct Permit {
        uint64 validUntil; // 0: no permit
        uint32 milestone;
        bytes32 evidence; // digest of the signed response it is based on
    }

    struct Order {
        address buyer;
        address payable supplier; // fixed at creation, nobody can change it
        bytes32 companyRequest; // AirnodeHub request hash of this supplier's company profile
        string companyNumber; // Companies House number, e.g. "07418033"
        bytes32 orderRef; // invoice / purchase order id
        uint64 permitTtl; // seconds a permit stays valid
        uint32 paidCount; // milestones paid so far (= index of the next milestone)
        State state;
        uint256 paid;
        uint256[] amounts;
        bool[] approved;
        Permit permit;
        bytes lastStatus;
        uint256 lastCheck; // AirnodeHub timestamp of the last accepted evidence
    }

    address public admin;
    address public airnode; // the only signer we accept (registry Airnode)
    uint256 public maxAge; // seconds a signed response stays usable
    uint256 public constant MAX_FUTURE_SKEW = 60;
    bytes public statusKey; // JSON bytes right before the status string, e.g. `"status":`
    bytes32 public constant ACTIVE = keccak256("active");

    mapping(bytes32 => bool) public usedDigests;
    Order[] internal orders;

    event OrderCreated(
        uint256 indexed orderId,
        address indexed buyer,
        address supplier,
        bytes32 companyRequest,
        bytes32 orderRef,
        uint256 total,
        uint256 milestones
    );
    event OrderCompany(uint256 indexed orderId, string companyNumber, bytes32 companyRequest);
    event MilestoneApproved(uint256 indexed orderId, uint256 milestone);
    event EvidenceAccepted(uint256 indexed orderId, bytes status, uint256 timestamp, bytes32 digest, address submitter);
    event PermitIssued(uint256 indexed orderId, uint256 milestone, uint256 amount, uint256 validUntil, bytes32 evidence);
    event MilestonePaid(uint256 indexed orderId, uint256 milestone, address supplier, uint256 amount, bytes32 evidence);
    event OrderHeld(uint256 indexed orderId, bytes status, uint256 remaining);
    event OrderRefunded(uint256 indexed orderId, address buyer, uint256 amount);
    event ConfigUpdated(address airnode, uint256 maxAge);

    error WrongSigner(address recovered);
    error WrongRequest(bytes32 got, bytes32 expected);
    error StaleResponse(uint256 timestamp, uint256 nowTs);
    error FutureResponse(uint256 timestamp, uint256 nowTs);
    error Replayed(bytes32 digest);
    error NotNewer(uint256 timestamp, uint256 lastCheck);
    error NoValidPermit(uint256 milestone);
    error PermitExpired(uint256 validUntil, uint256 nowTs);
    error NotApproved(uint256 milestone);
    error NotActive(State state);
    error NotHeld();
    error BadOrder();
    error BadCompanyNumber();
    error NotAuthorized();
    error TransferFailed();

    constructor(address _airnode, uint256 _maxAge, bytes memory _statusKey) {
        admin = msg.sender;
        airnode = _airnode;
        maxAge = _maxAge;
        statusKey = _statusKey;
        emit ConfigUpdated(_airnode, _maxAge);
    }

    // --------------------------------------------------------------- orders

    /// @notice Lock the whole order amount. `amounts` are the milestone payments, in order.
    function createOrder(
        address payable supplier,
        string calldata companyNumber,
        bytes32 orderRef,
        uint256[] calldata amounts,
        uint64 permitTtl
    ) external payable returns (uint256 id) {
        bytes32 companyRequest = companyRequestHash(companyNumber);
        if (supplier == address(0) || amounts.length == 0 || permitTtl == 0) {
            revert BadOrder();
        }
        uint256 total;
        for (uint256 i = 0; i < amounts.length; i++) {
            if (amounts[i] == 0) revert BadOrder();
            total += amounts[i];
        }
        if (msg.value != total) revert BadOrder();

        id = orders.length;
        Order storage o = orders.push();
        o.buyer = msg.sender;
        o.supplier = supplier;
        o.companyRequest = companyRequest;
        o.companyNumber = companyNumber;
        o.orderRef = orderRef;
        o.permitTtl = permitTtl;
        o.amounts = amounts;
        o.approved = new bool[](amounts.length);
        emit OrderCreated(id, msg.sender, supplier, companyRequest, orderRef, total, amounts.length);
        emit OrderCompany(id, companyNumber, companyRequest);
    }

    /// @notice Buyer confirms a milestone (order accepted, stage reached, delivery accepted).
    function approveMilestone(uint256 orderId, uint256 milestone) external {
        Order storage o = _order(orderId);
        if (msg.sender != o.buyer) revert NotAuthorized();
        if (milestone >= o.amounts.length) revert BadOrder();
        o.approved[milestone] = true;
        emit MilestoneApproved(orderId, milestone);
    }

    // ------------------------------------------------------------- evidence

    /// @notice Verify a signed company profile for this order. "active" issues a permit for the next
    /// milestone; any other status holds the order. Reverts on any verification failure.
    /// @param requestHash `requestHash` of the AirnodeHub response
    /// @param timestamp   `timestamp` of the response (unix seconds)
    /// @param data        the exact signed bytes (the `data` string)
    /// @param signature   `signature` (65 bytes)
    function submitEvidence(
        uint256 orderId,
        bytes32 requestHash,
        uint256 timestamp,
        bytes calldata data,
        bytes calldata signature
    ) public returns (bool active) {
        Order storage o = _order(orderId);
        if (o.state != State.Active) revert NotActive(o.state);
        if (requestHash != o.companyRequest) revert WrongRequest(requestHash, o.companyRequest);
        if (timestamp > block.timestamp + MAX_FUTURE_SKEW) revert FutureResponse(timestamp, block.timestamp);
        if (block.timestamp > timestamp && block.timestamp - timestamp > maxAge) {
            revert StaleResponse(timestamp, block.timestamp);
        }

        bytes32 d = AirnodeVerifier.digest(requestHash, timestamp, data);
        if (usedDigests[d]) revert Replayed(d);
        if (timestamp <= o.lastCheck) revert NotNewer(timestamp, o.lastCheck);

        address signer = AirnodeVerifier.recover(requestHash, timestamp, data, signature);
        if (signer != airnode) revert WrongSigner(signer);

        usedDigests[d] = true;
        bytes memory status = PriceParser.parseString(data, statusKey);
        o.lastStatus = status;
        o.lastCheck = timestamp;
        emit EvidenceAccepted(orderId, status, timestamp, d, msg.sender);

        if (keccak256(status) != ACTIVE) {
            o.state = State.Held;
            o.permit = Permit(0, 0, bytes32(0));
            emit OrderHeld(orderId, status, _remaining(o));
            return false;
        }

        // the permit is counted from the evidence time, not from when it was submitted
        uint64 validUntil = uint64(timestamp + o.permitTtl);
        o.permit = Permit(validUntil, o.paidCount, d);
        emit PermitIssued(orderId, o.paidCount, o.amounts[o.paidCount], validUntil, d);
        return true;
    }

    /// @notice Pay the next milestone with the current permit.
    function release(uint256 orderId) public {
        Order storage o = _order(orderId);
        if (o.state != State.Active) revert NotActive(o.state);
        uint256 m = o.paidCount;
        Permit memory p = o.permit;
        if (p.validUntil == 0 || p.milestone != m) revert NoValidPermit(m);
        if (block.timestamp > p.validUntil) revert PermitExpired(p.validUntil, block.timestamp);
        if (!o.approved[m]) revert NotApproved(m);

        uint256 amount = o.amounts[m];
        o.permit = Permit(0, 0, bytes32(0)); // used up: the next milestone needs new evidence
        o.paidCount = uint32(m + 1);
        o.paid += amount;
        if (o.paidCount == o.amounts.length) o.state = State.Closed;
        emit MilestonePaid(orderId, m, o.supplier, amount, p.evidence);
        (bool ok,) = o.supplier.call{value: amount}("");
        if (!ok) revert TransferFailed();
    }

    /// @notice One call for the agent: verify the evidence, then pay if the buyer approved the
    /// milestone. Does not revert when the order is held or waiting for approval, only on
    /// verification failures.
    function checkAndRelease(
        uint256 orderId,
        bytes32 requestHash,
        uint256 timestamp,
        bytes calldata data,
        bytes calldata signature
    ) external returns (Outcome outcome) {
        if (!submitEvidence(orderId, requestHash, timestamp, data, signature)) return Outcome.Held;
        if (!orders[orderId].approved[orders[orderId].paidCount]) return Outcome.AwaitingApproval;
        release(orderId);
        return Outcome.Paid;
    }

    /// @notice After a hold, the buyer takes back everything not yet paid.
    function refundRemaining(uint256 orderId) external {
        Order storage o = _order(orderId);
        if (msg.sender != o.buyer) revert NotAuthorized();
        if (o.state != State.Held) revert NotHeld();
        uint256 amount = _remaining(o);
        o.state = State.Closed;
        emit OrderRefunded(orderId, o.buyer, amount);
        (bool ok,) = o.buyer.call{value: amount}("");
        if (!ok) revert TransferFailed();
    }

    // ---------------------------------------------------------------- views

    /// @notice The only AirnodeHub request an order accepts: Companies House getCompanyProfile for
    /// this company number, projected to its status. Built here, so nobody can bind an order to a
    /// different company or query: requestHash = keccak256(JSON.stringify([operation, params, projection])).
    function companyRequestHash(string calldata companyNumber) public pure returns (bytes32) {
        bytes calldata n = bytes(companyNumber);
        if (n.length == 0 || n.length > 10) revert BadCompanyNumber();
        for (uint256 i = 0; i < n.length; i++) {
            bytes1 c = n[i];
            // register numbers are digits with an optional letter prefix (e.g. SC, OC); nothing to escape
            if (!((c >= "0" && c <= "9") || (c >= "A" && c <= "Z"))) revert BadCompanyNumber();
        }
        return keccak256(
            abi.encodePacked('["getCompanyProfile",[["company_number","', n, '"]],[["status","/company_status"]]]')
        );
    }

    function companyNumberOf(uint256 orderId) external view returns (string memory) {
        return _order(orderId).companyNumber;
    }

    function ordersLength() external view returns (uint256) {
        return orders.length;
    }

    /// @notice Everything the dashboard shows for one order.
    function orderStatus(uint256 orderId)
        external
        view
        returns (
            State state,
            uint256 paid,
            uint256 remaining,
            uint256 nextMilestone,
            uint256 milestones,
            uint256 permitValidUntil,
            bool permitValid,
            string memory lastStatus,
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
        permitValid = o.state == State.Active && p.validUntil != 0 && p.milestone == o.paidCount
            && block.timestamp <= p.validUntil;
        lastStatus = string(o.lastStatus);
        lastCheck = o.lastCheck;
    }

    function orderInfo(uint256 orderId)
        external
        view
        returns (
            address buyer,
            address supplier,
            bytes32 companyRequest,
            bytes32 orderRef,
            uint256 permitTtl,
            uint256[] memory amounts,
            bool[] memory approved
        )
    {
        Order storage o = _order(orderId);
        return (o.buyer, o.supplier, o.companyRequest, o.orderRef, o.permitTtl, o.amounts, o.approved);
    }

    function _order(uint256 orderId) internal view returns (Order storage) {
        if (orderId >= orders.length) revert BadOrder();
        return orders[orderId];
    }

    function _remaining(Order storage o) internal view returns (uint256 r) {
        if (o.state == State.Closed) return 0;
        for (uint256 i = o.paidCount; i < o.amounts.length; i++) {
            r += o.amounts[i];
        }
    }

    // ---------------------------------------------------------------- admin

    function setConfig(address _airnode, uint256 _maxAge) external {
        if (msg.sender != admin) revert NotAuthorized();
        airnode = _airnode;
        maxAge = _maxAge;
        emit ConfigUpdated(_airnode, _maxAge);
    }
}
