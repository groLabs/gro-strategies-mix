// SPDX-License-Identifier: AGPLv3
pragma solidity ^0.8.13;

interface IDSRPot {
    function chi() external view returns (uint256);

    function drip() external;
}
