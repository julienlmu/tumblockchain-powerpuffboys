// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Pulls a decimal number out of the raw JSON bytes that AirnodeHub signed,
/// e.g. `{"ethereum":{"usd":2987.41}}` with key `"usd":` gives 2987.41e18.
library PriceParser {
    error KeyNotFound();
    error NoNumber();
    error NoString();

    /// @param data      the signed response body
    /// @param key       bytes that come right before the number, e.g. `"usd":`
    /// @param sourceDecimals decimals already baked into the number (0 for "2987.41", 18 for "2987410000000000000000")
    /// @return price    value with 18 decimals
    function parse(bytes memory data, bytes memory key, uint8 sourceDecimals) internal pure returns (uint256 price) {
        uint256 i = _find(data, key);
        // skip whitespace and an optional opening quote
        while (i < data.length && (data[i] == " " || data[i] == '"')) i++;

        uint256 intPart;
        uint256 frac;
        uint256 fracDigits;
        bool seenDigit;
        bool inFrac;
        for (; i < data.length; i++) {
            bytes1 c = data[i];
            if (c >= "0" && c <= "9") {
                seenDigit = true;
                uint256 d = uint8(c) - 48;
                if (!inFrac) {
                    intPart = intPart * 10 + d;
                } else if (fracDigits < 18) {
                    frac = frac * 10 + d;
                    fracDigits++;
                }
            } else if (c == "." && !inFrac) {
                inFrac = true;
            } else {
                break;
            }
        }
        if (!seenDigit) revert NoNumber();
        price = intPart * 1e18 + frac * 10 ** (18 - fracDigits);
        price /= 10 ** sourceDecimals;
    }

    /// @notice Integer part of the number after `key`, e.g. `"updatedAt":1792403240691` gives 1792403240691
    function parseUint(bytes memory data, bytes memory key) internal pure returns (uint256) {
        return parse(data, key, 0) / 1e18;
    }

    /// @notice JSON string after `key`, e.g. `"status":"active"` with key `"status":` gives `active`
    function parseString(bytes memory data, bytes memory key) internal pure returns (bytes memory out) {
        uint256 i = _find(data, key);
        while (i < data.length && data[i] == " ") i++;
        if (i >= data.length || data[i] != '"') revert NoString();
        uint256 start = ++i;
        while (i < data.length && data[i] != '"') {
            if (data[i] == "\\") revert NoString(); // registry statuses never need escapes
            i++;
        }
        if (i >= data.length) revert NoString();
        out = new bytes(i - start);
        for (uint256 j = 0; j < out.length; j++) {
            out[j] = data[start + j];
        }
    }

    function _find(bytes memory data, bytes memory key) private pure returns (uint256) {
        if (key.length == 0 || data.length < key.length) revert KeyNotFound();
        for (uint256 i = 0; i <= data.length - key.length; i++) {
            bool ok = true;
            for (uint256 j = 0; j < key.length; j++) {
                if (data[i + j] != key[j]) {
                    ok = false;
                    break;
                }
            }
            if (ok) return i + key.length;
        }
        revert KeyNotFound();
    }
}
