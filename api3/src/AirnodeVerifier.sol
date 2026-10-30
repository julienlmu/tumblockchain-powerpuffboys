// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Verifies AirnodeHub signed responses.
/// AirnodeHub signs: digest = keccak256(abi.encodePacked(bytes32 requestHash, uint256 timestamp, bytes data))
/// with an EIP-191 personal_sign over the 32-byte digest.
library AirnodeVerifier {
    error InvalidSignatureLength();
    error InvalidSignatureS();
    error InvalidSignatureV();
    error InvalidSigner();

    // secp256k1n / 2, rejects malleable (high-s) signatures
    uint256 private constant HALF_N = 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0;

    function digest(bytes32 requestHash, uint256 timestamp, bytes memory data) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(requestHash, timestamp, data));
    }

    function ethSignedHash(bytes32 d) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", d));
    }

    function recover(bytes32 requestHash, uint256 timestamp, bytes memory data, bytes memory signature)
        internal
        pure
        returns (address)
    {
        if (signature.length != 65) revert InvalidSignatureLength();
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }
        if (v < 27) v += 27;
        if (v != 27 && v != 28) revert InvalidSignatureV();
        if (uint256(s) > HALF_N) revert InvalidSignatureS();
        address signer = ecrecover(ethSignedHash(digest(requestHash, timestamp, data)), v, r, s);
        if (signer == address(0)) revert InvalidSigner();
        return signer;
    }
}
