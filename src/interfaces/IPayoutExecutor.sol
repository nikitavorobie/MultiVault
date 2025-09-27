// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IPayoutExecutor {
    enum PayoutType {
        OneTime,
        Vesting,
        Streaming
    }

    event PayoutCreated(uint256 indexed payoutId, address indexed recipient, PayoutType payoutType);
    event PayoutClaimed(uint256 indexed payoutId, uint256 amount);

    function claim(uint256 payoutId) external;
    function getClaimableAmount(uint256 payoutId) external view returns (uint256);
}
