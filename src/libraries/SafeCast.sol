// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library SafeCast {
    error Overflow();

    function toUint128(uint256 value) internal pure returns (uint128) {
        if (value > type(uint128).max) revert Overflow();
        return uint128(value);
    }

    function toUint64(uint256 value) internal pure returns (uint64) {
        if (value > type(uint64).max) revert Overflow();
        return uint64(value);
    }
}
