// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library SignerLib {
    function validateWeight(uint256 weight) internal pure returns (bool) {
        return weight > 0 && weight <= 10000;
    }

    function validateThreshold(
        uint256 threshold,
        uint256 totalWeight
    ) internal pure returns (bool) {
        return threshold > 0 && threshold <= totalWeight;
    }

    function calculateNewTotalWeight(
        uint256 currentTotal,
        uint256 oldWeight,
        uint256 newWeight
    ) internal pure returns (uint256) {
        return currentTotal - oldWeight + newWeight;
    }
}
