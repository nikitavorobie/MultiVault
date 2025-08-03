// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library ProposalLib {
    struct ProposalStatus {
        bool isPending;
        bool isApproved;
        bool isExecuted;
        bool isCancelled;
        uint256 approvalPercentage;
    }

    function calculateApprovalPercentage(
        uint256 approvalWeight,
        uint256 totalWeight
    ) internal pure returns (uint256) {
        if (totalWeight == 0) return 0;
        return (approvalWeight * 100) / totalWeight;
    }

    function meetsThreshold(
        uint256 approvalWeight,
        uint256 threshold
    ) internal pure returns (bool) {
        return approvalWeight >= threshold;
    }

    function isExpired(
        uint256 createdAt,
        uint256 expirationPeriod
    ) internal view returns (bool) {
        return block.timestamp > createdAt + expirationPeriod;
    }
}
