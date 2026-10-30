// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// Order documents for SupplierPulse+ (additive to ISupplierPulsePlus, which stays unchanged).
/// An order's document is anchored as a salted hash, keccak256(salt ++ document), in `orderRef`
/// (scripts/plus-doc-hash.sh). The buyer picks one of two modes when creating the order:
///   0 Locked     (createOrder)          the anchored hash can never change
///   1 Amendable  (createAmendableOrder) a new hash is accepted only with signatures of both buyer and
///                                       supplier, and it is appended: every earlier version stays readable
interface IOrderDocuments {
    event DocumentAmended(uint256 indexed orderId, uint256 version, bytes32 previousHash, bytes32 newHash);

    error DocumentLocked(uint256 orderId);
    error BadDocumentHash();
    error BadAmendSignature(address recovered, address expected);

    function createAmendableOrder(
        uint8 source,
        string calldata supplierId,
        address payable supplier,
        bytes32 docHash,
        uint256[] calldata amounts,
        uint64[] calldata dueDates,
        uint64 permitTtl,
        uint8 rules
    ) external payable returns (uint256 orderId);

    /// Anyone may submit; both signatures are EIP-191 over amendmentDigest(orderId, newHash).
    function amendDocument(uint256 orderId, bytes32 newHash, bytes calldata buyerSig, bytes calldata supplierSig)
        external;

    /// What buyer and supplier sign for the next version: binds chain, contract, order, version and both hashes.
    function amendmentDigest(uint256 orderId, bytes32 newHash) external view returns (bytes32);

    /// mode 0 Locked / 1 Amendable; current = latest hash; version 0 = the hash given at creation
    function documentOf(uint256 orderId) external view returns (uint8 mode, bytes32 current, uint256 version);

    /// every version, oldest first (index 0 = orderRef)
    function documentHistory(uint256 orderId) external view returns (bytes32[] memory);
}
