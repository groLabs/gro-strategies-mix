// SPDX-License-Identifier: AGPLv3
pragma solidity ^0.8.13;

import "./BaseStrategy.sol";
import "./interfaces/IFluxToken.sol";

library FluxIntegrationErrors {
    error MintFailed(); // 0x4e4f4e45
    error RedeemFailed(); // 0x52454445
}

//⠀⠀⠘⡀⠀⠀⠀⠀⠀How about⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡜⠀⠀⠀
//⠀⠀⠀⠑⡀⠀⠀⠀20 % yield on⠀⠀⠀⠀⠀⠀⡔⠁⠀⠀⠀
//⠀⠀⠀⠀⠈⠢⢄⠀⠀⠀⠀Stables?⠀⠀⠀⠀⣀⠴⠊⠀⠀⠀⠀⠀
//⠀⠀⠀⠀⠀⠀⠀⢸⠀⠀⠀⢀⣀⣀⣀⣀⣀⡀⠤⠄⠒⠈⠀⠀⠀⠀⠀⠀⠀⠀
//⠀⠀⠀⠀⠀⠀⠀⠘⣀⠄⠊⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
//⠀
//⣿⣿⣿⣿⣿⣿⣿⣿⡿⠿⠛⠛⠛⠋⠉⠈⠉⠉⠉⠉⠛⠻⢿⣿⣿⣿⣿⣿⣿⣿
//⣿⣿⣿⣿⣿⡿⠋⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠛⢿⣿⣿⣿⣿
//⣿⣿⣿⣿⡏⣀⠀⠀⠀⠀⠀⠀⠀⣀⣤⣤⣤⣄⡀⠀⠀⠀⠀⠀⠀⠀⠙⢿⣿⣿
//⣿⣿⣿⢏⣴⣿⣷⠀⠀⠀⠀⠀⢾⣿⣿⣿⣿⣿⣿⡆⠀⠀⠀⠀⠀⠀⠀⠈⣿⣿
//⣿⣿⣟⣾⣿⡟⠁⠀⠀⠀⠀⠀⢀⣾⣿⣿⣿⣿⣿⣷⢢⠀⠀⠀⠀⠀⠀⠀⢸⣿
//⣿⣿⣿⣿⣟⠀⡴⠄⠀⠀⠀⠀⠀⠀⠙⠻⣿⣿⣿⣿⣷⣄⠀⠀⠀⠀⠀⠀⠀⣿
//⣿⣿⣿⠟⠻⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠶⢴⣿⣿⣿⣿⣿⣧⠀⠀⠀⠀⠀⠀⣿
//⣿⣁⡀⠀⠀⢰⢠⣦⠀⠀⠀⠀⠀⠀⠀⠀⢀⣼⣿⣿⣿⣿⣿⡄⠀⣴⣶⣿⡄⣿
//⣿⡋⠀⠀⠀⠎⢸⣿⡆⠀⠀⠀⠀⠀⠀⣴⣿⣿⣿⣿⣿⣿⣿⠗⢘⣿⣟⠛⠿⣼
//⣿⣿⠋⢀⡌⢰⣿⡿⢿⡀⠀⠀⠀⠀⠀⠙⠿⣿⣿⣿⣿⣿⡇⠀⢸⣿⣿⣧⢀⣼
//⣿⣿⣷⢻⠄⠘⠛⠋⠛⠃⠀⠀⠀⠀⠀⢿⣧⠈⠉⠙⠛⠋⠀⠀⠀⣿⣿⣿⣿⣿
//⣿⣿⣧⠀⠈⢸⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠟⠀⠀⠀⠀⢀⢃⠀⠀⢸⣿⣿⣿⣿
//⣿⣿⡿⠀⠴⢗⣠⣤⣴⡶⠶⠖⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⡸⠀⣿⣿⣿⣿
//⣿⣿⣿⡀⢠⣾⣿⠏⠀⠠⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠛⠉⠀⣿⣿⣿⣿
//⣿⣿⣿⣧⠈⢹⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣰⣿⣿⣿⣿
//⣿⣿⣿⣿⡄⠈⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣠⣴⣾⣿⣿⣿⣿⣿
//⣿⣿⣿⣿⣧⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣠⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿
//⣿⣿⣿⣿⣷⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣴⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
//⣿⣿⣿⣿⣿⣦⣄⣀⣀⣀⣀⠀⠀⠀⠀⠘⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
//⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⡄⠀⠀⠀⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
//⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣧⠀⠀⠀⠙⣿⣿⡟⢻⣿⣿⣿⣿⣿⣿⣿⣿⣿
//⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠇⠀⠁⠀⠀⠹⣿⠃⠀⣿⣿⣿⣿⣿⣿⣿⣿⣿
//⣿⣿⣿⣿⣿⣿⣿⣿⡿⠛⣿⣿⠀⠀⠀⠀⠀⠀⠀⠀⢐⣿⣿⣿⣿⣿⣿⣿⣿⣿
//⣿⣿⣿⣿⠿⠛⠉⠉⠁⠀⢻⣿⡇⠀⠀⠀⠀⠀⠀⢀⠈⣿⣿⡿⠉⠛⠛⠛⠉⠉
//⣿⡿⠋⠁⠀⠀⢀⣀⣠⡴⣸⣿⣇⡄⠀⠀⠀⠀⢀⡿⠄⠙⠛⠀⣀⣠⣤⣤⠄⠀
contract FluxStrategy is BaseStrategy {
    using Address for address;

    enum Stablecoin {
        DAI,
        USDC,
        USDT
    }

    IFLuxToken internal immutable _underlyingAsset;

    constructor(address _vault, address _asset) BaseStrategy(_vault) {
        require(_asset.isContract(), "Asset address is not a contract");
        _underlyingAsset = IFLuxToken(_asset);
    }

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
        (uint256 assets, , ) = _estimatedTotalAssets(); // Assets are in underlying asset(i.e. non 3CRV)
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
        if (profit > profitThreshold && timeSinceLastHarvest > MIN_REPORT_DELAY)
            return true;

        return false;
    }

    /// @notice Returns underlying asset
    function asset() external view returns (address) {
        return address(_underlyingAsset);
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL CORE LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Reports back any gains/losses that the strategy has made to the vault
    ///     and gets additional credit/pays back debt depending on credit availability
    function runHarvest() external {
        if (!keepers[msg.sender]) revert StrategyErrors.NotKeeper();
        if (stop) revert StrategyErrors.Stopped();
        (uint256 excessDebt, uint256 debtRatio) = _gVault.excessDebt(
            address(this)
        );
        uint256 profit;
        uint256 loss;
        uint256 debtRepayment;

        uint256 balance;
        bool emergency;
        // separate logic for emergency mode which needs implementation
        if (emergencyMode) {
            _divestAll(false);
            emergency = true;
            debtRepayment = _underlyingAsset.balanceOf(address(this));
            uint256 debt = _gVault.getStrategyDebt();
            if (debt > debtRepayment) loss = debt - debtRepayment;
            else profit = debtRepayment - debt;
        } else {
            (profit, loss, debtRepayment, balance) = _realisePnl(
                excessDebt,
                debtRatio
            );
        }
        uint256 credit = _gVault.report(profit, loss, debtRepayment, emergency);

        // invest any free funds in the strategy
        if (balance + credit > debtRepayment + INVESTMENT_BUFFER) {
            _invest(balance + credit - debtRepayment);
        }

        emit Harvested(profit, loss, debtRepayment, excessDebt);
    }

    /// @notice Withdraw assets from the strategy to the Vault -
    ///    If the strategy has a loss, this loss will be distributed
    ///     proportionally on the user withdrawing
    /// @param _amount asset quantity needed to be withdrawn by Vault
    /// @return withdrawnAssets amount of assets that were withdrawn from the strategy
    /// @return loss amount of loss that occurred during withdrawal
    function withdraw(
        uint256 _amount
    ) external virtual returns (uint256 withdrawnAssets, uint256 loss) {
        if (msg.sender != address(_gVault)) revert StrategyErrors.NotVault();
        (uint256 assets, uint256 balance, ) = _estimatedTotalAssets();
        uint256 debt = _gVault.getStrategyDebt();
        // not enough assets to withdraw
        if (_amount >= assets && _amount == debt) {
            balance += _divestAll(false);
            if (_amount > balance) {
                loss = _amount - balance;
                withdrawnAssets = balance;
            } else {
                withdrawnAssets = _amount;
            }
        } else {
            // check if there is a loss, and distribute it proportionally
            //  if it exists
            if (debt > assets) {
                loss = ((debt - assets) * _amount) / debt;
                _amount = _amount - loss;
            }
            if (_amount <= balance) {
                withdrawnAssets = _amount;
            } else {
                withdrawnAssets = _divest(_amount - balance, false) + balance;
                if (withdrawnAssets <= _amount) {
                    loss += _amount - withdrawnAssets;
                } else {
                    if (loss > withdrawnAssets - _amount) {
                        loss -= withdrawnAssets - _amount;
                    } else {
                        loss = 0;
                    }
                }
            }
        }
        _underlyingAsset.transfer(msg.sender, withdrawnAssets);
        return (withdrawnAssets, loss);
    }

    /// @notice Pulls out all funds into strategies base asset and stops
    ///     the strategy from being able to run harvest. Reports back
    ///     any gains/losses from this action to the vault
    function stopLoss() external virtual returns (bool) {
        if (!keepers[msg.sender]) revert StrategyErrors.NotKeeper();
        if (_divestAll(true) == 0) {
            stopLossAttempts += 1;
            return false;
        }
        uint256 debt = _gVault.getStrategyDebt();
        uint256 balance = _underlyingAsset.balanceOf(address(this));
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

    /// @notice Invest loose assets into current position and mint fTokens
    /// @dev Reverts if minting function returns non-zero value
    /// @param _credit Amount available to invest
    function _invest(uint256 _credit) internal override returns (uint256) {
        uint256 success = _underlyingAsset.mint(_credit);
        if (success != 0) revert FluxIntegrationErrors.MintFailed();
        return _underlyingAsset.balanceOf(address(this));
    }

    /// @notice Attempts to remove assets from active position
    /// @param _debt Amount to divest from position
    /// @param _slippage ignore slippage as Flux is not AMM
    /// @return amount of assets that were divested
    function _divest(
        uint256 _debt,
        bool _slippage
    ) internal override returns (uint256) {
        uint256 balance = _underlyingAsset.balanceOf(address(this));
        uint256 success = _underlyingAsset.redeem(_debt);
        if (success != 0) revert FluxIntegrationErrors.RedeemFailed();
        return balance - _underlyingAsset.balanceOf(address(this));
    }

    /// @notice Remove all assets from active position
    /// @param _slippage ignore slippage as Flux is not AMM
    /// @return amount of assets that were divested
    function _divestAll(bool _slippage) internal override returns (uint256) {
        uint256 balance = _underlyingAsset.balanceOf(address(this));
        uint256 success = _underlyingAsset.redeem(balance);
        if (success != 0) revert FluxIntegrationErrors.RedeemFailed();
        return balance;
    }

    /// @notice Strategy estimated total assets
    /// @return assets total assets, balance strategy balance, rewardAmounts reward amounts
    function _estimatedTotalAssets()
        internal
        view
        override
        returns (uint256, uint256, uint256)
    {
        uint256 _balance = _underlyingAsset.balanceOf(address(this));
        uint256 fAssets;
        // TODO: Implement fetching balance for Flux finance fTokens
        //        uint256 fAssets = someFunc();
        return (
            _balance + fAssets,
            _balance,
            // No rewards for this strategy
            0
        );
    }

    /// @notice Calculated the strategies current PnL and attempts to pay back any excess
    ///     debt the strategy has to the vault.
    /// @param _excessDebt Amount of debt that the strategy should pay back
    /// @param _debtRatio ratio of total vault assets the strategy is entitled to
    function _realisePnl(
        uint256 _excessDebt,
        uint256 _debtRatio
    ) internal override returns (uint256, uint256, uint256, uint256) {
        return (0, 0, 0, 0);
    }
}
