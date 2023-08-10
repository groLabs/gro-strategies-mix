// SPDX-License-Identifier: AGPLv3
pragma solidity ^0.8.13;

interface IStrategy {
    function asset() external view returns (address);

    function vault() external view returns (address);

    function estimatedTotalAssets() external view returns (uint256);

    function withdraw(uint256 _amount) external returns (uint256, uint256);

    function canHarvest() external view returns (bool);

    function runHarvest() external;

    function canStopLoss() external view returns (bool);

    function stopLoss() external returns (bool);

    function getMetaPool() external view returns (address);
}
