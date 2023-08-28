// SPDX-License-Identifier: AGPLv3
pragma solidity ^0.8.13;

import {IGVault} from "./interfaces/IGVault.sol";
import {ERC20} from "../lib/solmate/src/tokens/ERC20.sol";
import "./interfaces/IStrategy.sol";
import "./interfaces/IStop.sol";
import "../lib/openzeppelin-contracts/contracts/utils/Address.sol";

library GenericStrategyErrors {
    error NotOwner(); // 0x30cd7471
    error NotVault(); // 0x62df0545
    error NotKeeper(); // 0xf512b278
    error Stopped(); // 0x7acc84e3
    error BaseAsset(); // 0xaeca768b
    error ExcessDebtGtThanAssets(); // 0x961696d0
    error SlippageProtection(); // 0x17d431f4
}

abstract contract BaseStrategy is IStrategy {
    using Address for address;
    /*//////////////////////////////////////////////////////////////
                        CONSTANTS & IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant DEFAULT_DECIMALS_FACTOR = 1e18;
    uint256 internal constant PERCENTAGE_DECIMAL_FACTOR = 1e4;
    uint256 internal constant INVESTMENT_BUFFER = 10e18;
    uint256 public constant MAX_REPORT_DELAY = 604800;
    uint256 public constant MIN_REPORT_DELAY = 172800;
    uint256 public constant DECIMALS_FACTOR = 1e18;

    IGVault internal immutable _gVault;
    // Most likely 3crv
    ERC20 public immutable baseAsset;
    /*//////////////////////////////////////////////////////////////
                        STORAGE VARIABLES
    //////////////////////////////////////////////////////////////*/
    bool public emergencyMode;
    bool public stop;

    mapping(address => bool) public keepers;
    address public owner; // contract owner
    address public stopLossLogic;
    uint256 public stopLossAttempts;

    uint256 internal profitThreshold = 20_000 * DEFAULT_DECIMALS_FACTOR;
    uint256 internal debtThreshold = 5000 * DEFAULT_DECIMALS_FACTOR;

    uint256 public baseSlippage = 10; // In basis points
    uint256 public partialDivestSlippage = 10; // In basis points
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    event Harvested(
        uint256 profit,
        uint256 loss,
        uint256 debtRepayment,
        uint256 excessDebt
    );

    event LogNewStopLoss(address newStopLoss);

    constructor(address _vault) {
        require(_vault.isContract(), "Vault address is not a contract");
        _gVault = IGVault(_vault);
        baseAsset = _gVault.asset();
    }

    event NewKeeper(address indexed keeper);
    event EmergencyModeSet(bool mode);
    event SlippageSet(uint256 slippage);

    /*//////////////////////////////////////////////////////////////
                        VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice Checks if the strategy should be harvested
    function canHarvest() external view virtual returns (bool) {
        (bool active, uint256 totalDebt, uint256 lastReport) = _gVault
            .getStrategyData();

        // Should not trigger if strategy is not activated
        if (!active) return false;
        if (stop) return false;

        // Should trigger if hadn't been called in a while
        uint256 timeSinceLastHarvest = block.timestamp - lastReport;
        if (timeSinceLastHarvest > MAX_REPORT_DELAY) return true;

        // Check for profits and losses
        (uint256 assets, , ) = _estimatedTotalAssets();
        uint256 debt = totalDebt;
        (uint256 excessDebt, ) = _gVault.excessDebt(address(this));
        uint256 profit;
        if (assets > debt) {
            profit = assets - debt;
        } else {
            excessDebt += debt - assets;
        }
        profit += _gVault.creditAvailable();
        if (excessDebt > debtThreshold) return true;
        if (
            profit > profitThreshold && timeSinceLastHarvest > MIN_REPORT_DELAY
        ) {
            return true;
        }

        return false;
    }

    /// @notice Returns underlying vault
    function vault() external view returns (address) {
        return address(_gVault);
    }

    /// @notice Get strategies current assets
    function estimatedTotalAssets() external view virtual returns (uint256) {
        (uint256 _assets, , ) = _estimatedTotalAssets();
        return _assets;
    }

    /// @notice Check if stop loss needs to be triggered
    function canStopLoss() external view virtual returns (bool) {
        if (stop) return false;
        IStop _stopLoss = IStop(stopLossLogic);
        if (address(_stopLoss) == address(0)) return false;
        return _stopLoss.stopLossCheck();
    }

    /// @notice Get current curve meta pool
    /// @dev This is a placeholder function to implement in case strategy invests in crv/cvx
    function getMetaPool() external view virtual returns (address) {
        return address(0);
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice Set new stop loss logic
    function setStopLossLogic(address _newStopLoss) external {
        if (msg.sender != owner) revert GenericStrategyErrors.NotOwner();
        stopLossLogic = _newStopLoss;
        emit LogNewStopLoss(_newStopLoss);
    }

    function setSlippage(uint256 _slippage) external {
        if (msg.sender != owner) revert GenericStrategyErrors.NotOwner();
        baseSlippage = _slippage;
        emit SlippageSet(_slippage);
    }

    /// @notice Add keeper from the strategy
    /// @param _keeper keeper to add
    function setKeeper(address _keeper) external {
        if (msg.sender != owner) revert GenericStrategyErrors.NotOwner();
        keepers[_keeper] = true;

        emit NewKeeper(_keeper);
    }

    /// @notice Pulls out all funds into strategies base asset and stops
    ///     the strategy from being able to run harvest. Reports back
    ///     any gains/losses from this action to the vault
    function stopLoss() external virtual returns (bool) {
        if (!keepers[msg.sender]) revert GenericStrategyErrors.NotKeeper();
        if (_divestAll(true) == 0) {
            stopLossAttempts += 1;
            return false;
        }
        uint256 debt = _gVault.getStrategyDebt();
        uint256 balance = baseAsset.balanceOf(address(this));
        uint256 loss;
        uint256 profit;
        // we expect losses, but should account for a situation that
        //     produces gains
        if (debt > balance) {
            loss = debt - balance;
        } else {
            profit = balance - debt;
        }
        // We dont attempt to repay anything - follow up actions need
        //  to be taken to withdraw any assets from the strategy
        _gVault.report(profit, loss, 0, false);
        stop = true;
        stopLossAttempts = 0;
        return true;
    }

    /// @notice Restarts strategy after stop-loss has been triggered
    function resume() external {
        if (msg.sender != owner) revert GenericStrategyErrors.NotOwner();
        stop = false;
    }

    /// @notice Sets emergency mode to enable emergency exit of strategy
    function setEmergencyMode() external {
        if (!keepers[msg.sender]) revert GenericStrategyErrors.NotKeeper();
        emergencyMode = true;

        emit EmergencyModeSet(true);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Invest loose assets into current position
    /// @param _credit Amount available to invest
    function _invest(uint256 _credit) internal virtual returns (uint256);

    /// @notice Attempts to remove assets from active position
    /// @param _debt Amount to divest from position
    /// @param _slippage control for when harvest divests in case strategy invests in AMM
    function _divest(
        uint256 _debt,
        bool _slippage
    ) internal virtual returns (uint256);

    /// @notice Remove all assets from active position
    /// @param _slippage Slippage control for invest function in case strategy invests in AMM
    function _divestAll(bool _slippage) internal virtual returns (uint256);

    /// @notice Internal call of function above
    /// @return assets total assets, balance strategy balance, rewardAmounts reward amounts
    function _estimatedTotalAssets()
        internal
        view
        virtual
        returns (uint256, uint256, uint256);

    /// @notice Calculated the strategies current PnL and attempts to pay back any excess
    ///     debt the strategy has to the vault.
    /// @param _excessDebt Amount of debt that the strategy should pay back
    /// @param _debtRatio ratio of total vault assets the strategy is entitled to
    function _realisePnl(
        uint256 _excessDebt,
        uint256 _debtRatio
    ) internal virtual returns (uint256, uint256, uint256, uint256) {
        uint256 profit;
        uint256 loss;
        uint256 debtRepayment;

        uint256 debt = _gVault.getStrategyDebt();

        (uint256 assets, uint256 balance, ) = _estimatedTotalAssets();
        // Early revert
        if (_excessDebt > assets) {
            revert GenericStrategyErrors.ExcessDebtGtThanAssets();
        } else {
            // If current assets are greater than debt, we have profit
            if (assets > debt) {
                profit = assets - debt;
                uint256 profitToRepay = 0;
                if (profit > profitThreshold) {
                    profitToRepay =
                        (profit * (PERCENTAGE_DECIMAL_FACTOR - _debtRatio)) /
                        PERCENTAGE_DECIMAL_FACTOR;
                }
                if (profitToRepay + _excessDebt > balance) {
                    balance = _divest(
                        profitToRepay + _excessDebt - balance,
                        true
                    );
                    debtRepayment = balance;
                } else {
                    debtRepayment = profitToRepay + _excessDebt;
                }
                // If current assets are less than debt, we have loss
            } else if (assets < debt) {
                loss = debt - assets;
                // here for safety, but should really never be the case
                //  that loss > _excessDebt
                if (loss > _excessDebt) {
                    debtRepayment = 0;
                } else if (balance < _excessDebt - loss) {
                    balance = _divest(_excessDebt - loss - balance, true);
                    debtRepayment = balance;
                } else {
                    debtRepayment = _excessDebt - loss;
                }
            }
        }
        return (profit, loss, debtRepayment, balance);
    }
}
