// SPDX-License-Identifier: AGPLv3
pragma solidity ^0.8.13;

import "./BaseStrategy.sol";
import "./interfaces/ICurve3Pool.sol";
import "./interfaces/IDSRManager.sol";
import {ERC20} from "../lib/solmate/src/tokens/ERC20.sol";
import {SafeTransferLib} from "../lib/solmate/src/utils/SafeTransferLib.sol";
import "./interfaces/IDSRPot.sol";

library DSRIntegrationErrors {}

//           LETS GET SOME YIELD
//⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣖⠒⠊⠉⠉⠐⠒⠀⠀⠀⠀⠀⠀⠀⠀⣀⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
//⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠙⢷⣄⠀⠀⠀⠀⠀⢀⣤⣤⣤⣤⣤⣤⣿⣇⠀⠀⠀⠀⠀⠀⣀⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
//⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠳⣄⠀⠀⠀⠿⠋⠉⠈⠉⠉⠉⠛⠛⠓⠦⢤⣀⠀⠠⠿⠛⠛⠒⠂⢀⣀⣀⡀⠀⠀⠀⠀⠀⠀⠀⠀
//⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⢷⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣤⣤⡤⠿⢷⣦⣄⡀⠀⠀⣠⡾⠛⠉⣙⣷⣒⢶⢄⡀⠀⠀⠀
//⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠙⣄⠀⠀⠀⠀⠀⠀⣴⡾⠋⠁⣀⣤⡶⠶⠶⣮⣽⣶⣾⠏⣠⡶⠛⠉⢉⣍⠉⠻⣝⢦⡀⠀
//⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣿⡆⠀⠀⠀⠀⠀⣬⣤⣴⠟⠉⠀⠀⠀⠀⠀⠉⠙⢿⣶⠋⠀⠀⠀⢿⣿⣷⣦⡈⢻⡽⡀
//⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⠶⠋⠀⠀⠀⠀⠀⠀⠀⢿⣅⠀⠀⠀⠀⠀⣰⣾⣿⣦⠀⠀⢻⡆⠀⠀⠀⢸⣿⣿⠉⣷⡄⠹⡀
//⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⡶⠟⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠹⡆⠀⠀⠀⠀⣿⣿⠿⣿⡄⠀⠠⢣⠀⠀⠀⠀⢿⣿⣿⡿⠃⢀⣷
//⠀⠀⠀⠀⠀⠀⠀⢀⣴⠞⠋⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢰⡿⣿⠀⠀⠀⣸⣿⣟⣰⣿⠁⠀⠀⣸⣄⠀⠀⠀⠀⠈⣁⣠⡴⢛⡥
//⠀⠀⠀⠀⣠⡴⠞⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⣧⢹⣆⠀⠀⠹⣿⠿⠛⠁⠀⢀⣼⣏⠉⠙⣛⣛⣉⣭⡵⣶⣿⣿⠁
//⠀⠀⣠⠞⠋⠀⠀⠀⠀⠀⢀⣠⡶⠶⠶⣄⠀⠀⠀⠀⠀⣿⣄⠀⠀⢻⣄⠙⠷⢦⣤⣤⣤⣤⢶⣾⠏⠀⠙⢿⣦⣄⣀⣠⣴⠞⠋⠁⠀⢡
//⢠⡾⠁⠀⠀⠀⠀⠀⠀⣴⠛⢹⣄⠀⠀⠹⣷⣀⠀⠀⠀⠈⠙⠷⣤⣤⣈⣙⣳⣶⡶⠶⠟⠋⠁⠀⠀⠀⠀⠀⠈⢻⣏⠁⠀⠀⠀⠀⣰⣿
//⣾⠀⠀⠀⠀⠀⠀⠀⢸⡟⠀⣿⡟⢷⣄⠀⠈⠻⢷⣄⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣀⣤⣶⣿⣧⠿
//⣿⠀⠀⠀⠀⠀⠀⠀⠸⣷⠀⠸⣿⣄⠙⢿⣦⣄⣀⠈⠙⠻⠶⢤⣄⣀⣀⣀⡀⠀⠀⠀⠀⠀⠀⢀⣀⣀⣀⣠⣤⣶⣾⣿⡭⣷⣿⣿⠃⠀
//⢹⡀⠀⠀⠀⠀⠀⠀⠀⠹⣄⠀⠘⢿⣿⠿⠿⣿⣿⣿⡶⢤⣤⣀⣀⣉⣉⣉⣉⣛⣛⣛⣛⣻⣟⣫⡿⠿⠿⠾⠿⠿⢿⣭⠀⣼⣿⠏⠀⠀
//⠀⠳⡄⠀⠀⠀⠀⠀⠀⠀⠙⢷⣄⠀⠙⠳⢤⣀⡉⠛⠿⣷⣤⣉⡉⠉⠉⠙⠛⠛⠛⢛⣿⣿⡧⠀⠀⠀⠀⠀⢀⣠⣴⣿⣾⡿⠋⠀⠀⠀
//⠀⠀⠘⢦⡀⠀⠀⠀⠀⠀⠀⠀⠙⠷⣤⣀⠀⠉⠙⠳⠶⠤⣽⣿⣿⣿⣶⣶⣶⣶⡾⠿⣛⣉⣤⣤⢤⡴⣶⣿⡭⢿⡼⠟⠉⠀⠀⠀⠀⠀
//⠀⠀⠀⠀⠙⠢⣄⠀⠀⠀⠀⠀⠀⠀⠀⠙⠛⠲⠦⣤⣤⣀⣀⣀⣀⣀⣠⣬⣽⠿⠭⠿⠛⠓⡒⣛⠩⣴⠛⠁⠀⠈⠀⠀⠀⠀⠀⠀⠀⠀
//⠀⠀⠀⠀⠀⠀⠈⠑⠠⢤⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠉⠉⠛⠋⠉⠉⠀⣀⣀⡤⡄⠀⣉⣥⣃⡘⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
contract DSRStrategy is BaseStrategy {
    using Address for address;
    using SafeTransferLib for ERC20;

    /*//////////////////////////////////////////////////////////////
                        Constants
    //////////////////////////////////////////////////////////////*/
    uint256 public constant CHI_DECIMALS = 10e27;

    IDSRManager public constant DSR_MANAGER =
        IDSRManager(0x373238337Bfe1146fb49989fc222523f83081dDb);

    ICurve3Pool public constant THREE_POOL =
        ICurve3Pool(0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7);
    ERC20 public constant THREE_CRV =
        ERC20(0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490);
    ERC20 public constant DAI =
        ERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    uint256 public constant DAI_INDEX = 0;
    uint256 public constant BASIS_POINTS = 10000;
    /*//////////////////////////////////////////////////////////////
                        STORAGE VARIABLES
    //////////////////////////////////////////////////////////////*/
    IDSRPot public immutable pot;

    constructor(address _vault) BaseStrategy(_vault) {
        owner = msg.sender;
        THREE_CRV.approve(address(_gVault), type(uint256).max);
        DAI.approve(address(DSR_MANAGER), type(uint256).max);

        pot = IDSRPot(DSR_MANAGER.pot());
    }

    /*//////////////////////////////////////////////////////////////
                        VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns underlying asset
    function asset() external pure returns (address) {
        return address(DAI);
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL CORE LOGIC
    //////////////////////////////////////////////////////////////*/
    /// @notice Reports back any gains/losses that the strategy has made to the vault
    ///     and gets additional credit/pays back debt depending on credit availability
    function runHarvest() external {
        if (!keepers[msg.sender]) revert GenericStrategyErrors.NotKeeper();
        if (stop) revert GenericStrategyErrors.Stopped();
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
            debtRepayment = baseAsset.balanceOf(address(this));
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
    ) external override returns (uint256 withdrawnAssets, uint256 loss) {
        if (msg.sender != address(_gVault)) {
            revert GenericStrategyErrors.NotVault();
        }
        (uint256 assets, uint256 balance, ) = _estimatedTotalAssets();
        uint256 debt = _gVault.getStrategyDebt();
        // not enough assets to withdraw, so divest all and return what we have
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
                withdrawnAssets = _divest(_amount - balance, false);
                // Never give away more to the user than was requested
                if (withdrawnAssets < _amount) {
                    loss += _amount - withdrawnAssets;
                } else {
                    withdrawnAssets = _amount;
                }
            }
        }
        baseAsset.transfer(msg.sender, withdrawnAssets);
        return (withdrawnAssets, loss);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL LOGIC
    //////////////////////////////////////////////////////////////*/
    /// @notice Invest loose assets into DSR
    /// @param _credit Amount available to invest denominated in 3crv
    function _invest(uint256 _credit) internal override returns (uint256) {
        // First, we need to get back underlying asset from 3pool
        THREE_POOL.remove_liquidity_one_coin(
            _credit,
            int128(int256(DAI_INDEX)),
            0
        );
        uint256 underlyingBalance = DAI.balanceOf(address(this));
        // Now we can mint fToken
        DSR_MANAGER.join(address(this), underlyingBalance);
        return _credit;
    }

    /// @notice Attempts to remove assets from active DSR position
    /// @param _debt Amount to divest from position denominated in 3crv
    /// @param _slippage Whether to check for slippage or not
    /// @return amount of assets denominated in 3crv that were divested
    function _divest(
        uint256 _debt,
        bool _slippage
    ) internal override returns (uint256) {
        // Convert _debt denominated in 3crv to underlying token first
        uint256 estimatedUnderlyingValue = THREE_POOL.calc_withdraw_one_coin(
            _debt,
            int128(int256(DAI_INDEX))
        );
        if (_slippage) {
            // Convert withdrawn stablecoin to 3crv using get virtual price as it cannot be manipulated easily
            uint256 _estimated3crv = (estimatedUnderlyingValue *
                DEFAULT_DECIMALS_FACTOR) / THREE_POOL.get_virtual_price();
            if (_estimated3crv > _debt) {
                // Calculate slippage in basis points
                uint256 slippage = ((_estimated3crv - _debt) * BASIS_POINTS) /
                    _estimated3crv;
                if (slippage > partialDivestSlippage) {
                    revert GenericStrategyErrors.SlippageProtection();
                }
            }
        }
        // Now withdraw into DSR
        DSR_MANAGER.exit(address(this), estimatedUnderlyingValue);

        uint256[3] memory _amounts;
        // Now we need to swap redeemed underlying asset to 3crv
        // Balance to withdraw is calculated as difference between current balance and balance snapshot
        _amounts[DAI_INDEX] = DAI.balanceOf(address(this));
        // Add liquidity to 3pool
        THREE_POOL.add_liquidity(_amounts, 0);
        return baseAsset.balanceOf(address(this));
    }

    /// @notice Remove all assets from active position
    /// @param _slippage whether to check for slippage or not
    /// @return amount of assets denominated in 3crv that were divested
    function _divestAll(bool _slippage) internal override returns (uint256) {
        DSR_MANAGER.exitAll(address(this));
        // Convert redeemed underlying asset to 3crv
        uint256[3] memory _amounts;
        _amounts[DAI_INDEX] = DAI.balanceOf(address(this));
        uint256 threeCurveSnapshotBalance = THREE_CRV.balanceOf(address(this));
        THREE_POOL.add_liquidity(_amounts, 0);
        if (_slippage) {
            // Compare current debt to debt snapshot and check difference slippage,
            // Then, if slippage is too high, revert
            uint256 debt = _gVault.getStrategyDebt();
            // If there is profit and we are not in emergency mode, we can allow for some positive slippage
            if (
                debt >
                baseAsset.balanceOf(address(this)) - threeCurveSnapshotBalance
            ) {
                // Calculate slippage in basis points
                uint256 slippage = ((debt -
                    baseAsset.balanceOf(address(this))) * BASIS_POINTS) / debt;
                if (slippage > fullDivestSlippage) {
                    revert GenericStrategyErrors.SlippageProtection();
                }
            }
        }
        // Return amount of 3crv that was divested
        return baseAsset.balanceOf(address(this));
    }

    /// @notice Strategy estimated total assets
    /// @return assets total assets, balance strategy balance, rewardAmounts reward amounts
    function _estimatedTotalAssets()
        internal
        view
        override
        returns (uint256, uint256, uint256)
    {
        uint256 _balanceUnderlyingIn3Pool = baseAsset.balanceOf(address(this));
        uint256[3] memory _amounts;
        // Obtain balance of underlying asset in DSR plus accumulated interests
        uint256 _balanceUnderlyingPosition = (DSR_MANAGER.pieOf(address(this)) *
            pot.chi()) / CHI_DECIMALS;

        // "Simulate" deposit into 3pool to get amount of 3crv we can potentially get
        _amounts[DAI_INDEX] = _balanceUnderlyingPosition;
        uint256 _estimated3Crv = THREE_POOL.calc_token_amount(_amounts, true) +
            _balanceUnderlyingIn3Pool;
        return (
            _estimated3Crv,
            _balanceUnderlyingIn3Pool,
            // No rewards for this strategy
            0
        );
    }
}
