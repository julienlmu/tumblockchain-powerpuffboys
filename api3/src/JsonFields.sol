// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Reads JSON booleans out of the exact bytes an Airnode signed,
/// e.g. `{"insolvency":false}` with key `"insolvency":` gives false.
/// Strings are read with `PriceParser.parseString`.
library JsonFields {
    error KeyNotFound();
    error NoBool();

    /// @param key bytes that come right before the value, including the leading quote, e.g. `"insolvency":`
    function parseBool(bytes memory data, bytes memory key) internal pure returns (bool) {
        uint256 i = find(data, key);
        while (i < data.length && data[i] == " ") i++;
        if (_startsWith(data, i, "true")) return true;
        if (_startsWith(data, i, "false")) return false;
        revert NoBool();
    }

    /// @return index of the first byte after `key`
    function find(bytes memory data, bytes memory key) internal pure returns (uint256) {
        if (key.length == 0 || data.length < key.length) revert KeyNotFound();
        for (uint256 i = 0; i <= data.length - key.length; i++) {
            if (_startsWith(data, i, key)) return i + key.length;
        }
        revert KeyNotFound();
    }

    function _startsWith(bytes memory data, uint256 at, bytes memory word) private pure returns (bool) {
        if (at + word.length > data.length) return false;
        for (uint256 j = 0; j < word.length; j++) {
            if (data[at + j] != word[j]) return false;
        }
        return true;
    }
}
