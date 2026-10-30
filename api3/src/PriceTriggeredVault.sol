// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AirnodeVerifier} from "./AirnodeVerifier.sol";
import {PriceParser} from "./PriceParser.sol";

/// @title PriceTriggeredVault
/// @notice Holds ETH for orders like "if ETH < $3000, pay out to X". The price can only come from an
/// AirnodeHub signed response, checked on-chain for: trusted signer, expected request, freshness, no replay.
/// Anyone (our Cardano agent, or a judge with a script) can submit a signed response.
contract PriceTriggeredVault {
    struct Order {
        address owner;
        address payable beneficiary;
        uint256 amount;
        uint256 threshold; // USD price, 18 decimals
        bool below; // true: execute when price < threshold, false: when price > threshold
        bool done; // executed or cancelled
    }

    address public admin;
    address public airnode; // the only signer we accept
    bytes32 public requestHash; // the only AirnodeHub request we accept (ETH/USD)
    uint256 public maxAge; // seconds a signed response stays valid
    uint256 public constant MAX_FUTURE_SKEW = 60;
    bytes public priceKey; // JSON bytes right before the number, e.g. `"usd":`
    uint8 public sourceDecimals;

    uint256 public latestPrice; // 18 decimals
    uint256 public latestTimestamp; // AirnodeHub timestamp of latestPrice
    mapping(bytes32 => bool) public usedDigests;

    Order[] public orders;

    event PriceAccepted(uint256 price, uint256 timestamp, bytes32 digest, address submitter);
    event OrderCreated(uint256 indexed orderId, address indexed owner, address beneficiary, uint256 amount, uint256 threshold, bool below);
    event OrderExecuted(uint256 indexed orderId, uint256 price, uint256 timestamp, address beneficiary, uint256 amount);
    event OrderCancelled(uint256 indexed orderId);
    event ConfigUpdated(address airnode, bytes32 requestHash, uint256 maxAge);

    error WrongSigner(address recovered);
    error WrongRequest(bytes32 got);
    error StaleResponse(uint256 timestamp, uint256 nowTs);
    error FutureResponse(uint256 timestamp, uint256 nowTs);
    error Replayed(bytes32 digest);
    error NotNewer(uint256 timestamp, uint256 latest);
    error ConditionNotMet(uint256 price, uint256 threshold, bool below);
    error NoFreshPrice();
    error BadOrder();
    error NotAuthorized();
    error TransferFailed();

    constructor(
        address _airnode,
        bytes32 _requestHash,
        uint256 _maxAge,
        bytes memory _priceKey,
        uint8 _sourceDecimals
    ) {
        admin = msg.sender;
        airnode = _airnode;
        requestHash = _requestHash;
        maxAge = _maxAge;
        priceKey = _priceKey;
        sourceDecimals = _sourceDecimals;
        emit ConfigUpdated(_airnode, _requestHash, _maxAge);
    }

    // ---------------------------------------------------------------- price

    /// @notice Verify an AirnodeHub signed response and store its price.
    /// @param _requestHash X-Airnode-Request-Hash / `requestHash`
    /// @param timestamp    X-Airnode-Timestamp / `timestamp` (unix seconds)
    /// @param data         the exact signed bytes (response body / JSON.stringify(data))
    /// @param signature    X-Airnode-Signature / `signature` (65 bytes)
    function submitPrice(bytes32 _requestHash, uint256 timestamp, bytes calldata data, bytes calldata signature)
        public
        returns (uint256 price)
    {
        if (_requestHash != requestHash) revert WrongRequest(_requestHash);
        if (timestamp > block.timestamp + MAX_FUTURE_SKEW) revert FutureResponse(timestamp, block.timestamp);
        if (block.timestamp > timestamp && block.timestamp - timestamp > maxAge) {
            revert StaleResponse(timestamp, block.timestamp);
        }

        bytes32 d = AirnodeVerifier.digest(_requestHash, timestamp, data);
        if (usedDigests[d]) revert Replayed(d);
        if (timestamp <= latestTimestamp) revert NotNewer(timestamp, latestTimestamp);

        address signer = AirnodeVerifier.recover(_requestHash, timestamp, data, signature);
        if (signer != airnode) revert WrongSigner(signer);

        usedDigests[d] = true;
        price = PriceParser.parse(data, priceKey, sourceDecimals);
        latestPrice = price;
        latestTimestamp = timestamp;
        emit PriceAccepted(price, timestamp, d, msg.sender);
    }

    function hasFreshPrice() public view returns (bool) {
        return latestTimestamp != 0 && block.timestamp <= latestTimestamp + maxAge;
    }

    // --------------------------------------------------------------- orders

    /// @notice Lock ETH; it goes to `beneficiary` once a verified price crosses `threshold`.
    function createOrder(address payable beneficiary, uint256 threshold, bool below) external payable returns (uint256 id) {
        if (msg.value == 0 || beneficiary == address(0) || threshold == 0) revert BadOrder();
        id = orders.length;
        orders.push(Order(msg.sender, beneficiary, msg.value, threshold, below, false));
        emit OrderCreated(id, msg.sender, beneficiary, msg.value, threshold, below);
    }

    /// @notice Execute an order with the latest stored (still fresh) verified price.
    function execute(uint256 orderId) public {
        if (!hasFreshPrice()) revert NoFreshPrice();
        _execute(orderId, latestPrice, latestTimestamp);
    }

    /// @notice One call for the agent: verify the signed response, then execute the order.
    function submitAndExecute(
        uint256 orderId,
        bytes32 _requestHash,
        uint256 timestamp,
        bytes calldata data,
        bytes calldata signature
    ) external returns (uint256 price) {
        price = submitPrice(_requestHash, timestamp, data, signature);
        _execute(orderId, price, timestamp);
    }

    /// @notice Like submitAndExecute, but leaves the order open (instead of reverting) when the
    /// condition is not met. Still reverts on any verification failure.
    function submitAndTryExecute(
        uint256 orderId,
        bytes32 _requestHash,
        uint256 timestamp,
        bytes calldata data,
        bytes calldata signature
    ) external returns (uint256 price, bool executed) {
        price = submitPrice(_requestHash, timestamp, data, signature);
        if (orderId >= orders.length || orders[orderId].done) revert BadOrder();
        Order storage o = orders[orderId];
        if (o.below ? price < o.threshold : price > o.threshold) {
            _execute(orderId, price, timestamp);
            executed = true;
        }
    }

    function cancel(uint256 orderId) external {
        Order storage o = orders[orderId];
        if (msg.sender != o.owner) revert NotAuthorized();
        if (o.done) revert BadOrder();
        o.done = true;
        emit OrderCancelled(orderId);
        (bool ok,) = o.owner.call{value: o.amount}("");
        if (!ok) revert TransferFailed();
    }

    function ordersLength() external view returns (uint256) {
        return orders.length;
    }

    function _execute(uint256 orderId, uint256 price, uint256 timestamp) internal {
        if (orderId >= orders.length) revert BadOrder();
        Order storage o = orders[orderId];
        if (o.done) revert BadOrder();
        bool met = o.below ? price < o.threshold : price > o.threshold;
        if (!met) revert ConditionNotMet(price, o.threshold, o.below);
        o.done = true;
        emit OrderExecuted(orderId, price, timestamp, o.beneficiary, o.amount);
        (bool ok,) = o.beneficiary.call{value: o.amount}("");
        if (!ok) revert TransferFailed();
    }

    // ---------------------------------------------------------------- admin

    function setConfig(address _airnode, bytes32 _requestHash, uint256 _maxAge) external {
        if (msg.sender != admin) revert NotAuthorized();
        airnode = _airnode;
        requestHash = _requestHash;
        maxAge = _maxAge;
        emit ConfigUpdated(_airnode, _requestHash, _maxAge);
    }
}
