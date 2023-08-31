// SPDX-License-Identifier: AGPLv3
pragma solidity ^0.8.13;

import "./interfaces/IStop.sol";
import "./interfaces/IStrategy.sol";
import "./external/GVault.sol";
import {Owned} from "../lib/solmate/src/auth/Owned.sol";

contract StopLoss is IStop, Owned {
    GVault public immutable gVault;

    uint256 public snLThreshold = 10; // In basis points
    uint256 public constant BPS = 10000;

    event SnLThresholdSet(uint256 _snLThreshold);

    constructor(address _gVault) Owned(msg.sender) {
        gVault = GVault(_gVault);
    }

    function setSnlThreshold(uint256 _snLThreshold) external onlyOwner {
        snLThreshold = _snLThreshold;
        emit SnLThresholdSet(_snLThreshold);
    }

    /**
     * @notice Flux strategy stop loss logic
     * @dev This contract is checking if the strategy current assets are way below the snapshotted value in gVault
     * and if true, strategy should be stopped.
     */
    function stopLossCheck() external view override returns (bool) {
        IStrategy strategy = IStrategy(msg.sender);
        // Current strategy assets
        uint256 strategyAssets = strategy.estimatedTotalAssets();
        (, , , uint256 totalDebt, , ) = gVault.strategies(address(strategy));
        // If current strategy assets decreased by more than snLThreshold, return true
        if (strategyAssets < totalDebt) {
            uint256 diff = totalDebt - strategyAssets;
            uint256 diffBps = (diff * BPS) / totalDebt;
            if (diffBps > snLThreshold) {
                return true;
            }
        }
        return false;
    }
}
