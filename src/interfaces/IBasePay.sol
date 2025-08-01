// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IBasePay {
    function transfer(
        address token,
        address recipient,
        uint256 amount
    ) external returns (bool);

    function batchTransfer(
        address token,
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external returns (bool);
}
