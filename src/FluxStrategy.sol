// SPDX-License-Identifier: AGPLv3
pragma solidity ^0.8.13;

import "./BaseStrategy.sol";
import "./interfaces/IFluxToken.sol";
import "./interfaces/ICurve3Pool.sol";
import {ERC20} from "../lib/solmate/src/tokens/ERC20.sol";
import {SafeTransferLib} from "../lib/solmate/src/utils/SafeTransferLib.sol";
import {console2} from "../lib/forge-std/src/console2.sol";

library FluxIntegrationErrors {
    error MintFailed(); // 0x4e4f4e45
    error RedeemFailed(); // 0x52454445
    error UknownAssetPair(); // 0x554150
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
    using SafeTransferLib for ERC20;
    /*//////////////////////////////////////////////////////////////
                        Constants
    //////////////////////////////////////////////////////////////*/

    address public constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    address public constant F_USDC = 0x465a5a630482f3abD6d3b84B39B29b07214d19e5;
    address public constant F_DAI = 0xe2bA8693cE7474900A045757fe0efCa900F6530b;
    address public constant F_USDT = 0x81994b9607e06ab3d5cF3AffF9a67374f05F27d7;

    ICurve3Pool public constant THREE_POOL =
        ICurve3Pool(0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7);
    ERC20 public constant THREE_CRV =
        ERC20(0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490);
    uint256 public constant DAI_INDEX = 0;
    uint256 public constant USDC_INDEX = 1;
    uint256 public constant USDT_INDEX = 2;

    uint256 public constant BASIS_POINTS = 10000;
    /*//////////////////////////////////////////////////////////////
                        STORAGE VARIABLES
    //////////////////////////////////////////////////////////////*/
    ERC20 internal immutable _underlyingAsset;
    IFluxToken public immutable _fToken;
    uint256 public immutable underlyingAssetIndex;
    uint256 public baseSlippage = 10; // In basis points

    constructor(
        address _vault,
        address _asset,
        address _fTokenAddr
    ) BaseStrategy(_vault) {
        require(_asset.isContract(), "Asset address is not a contract");
        require(_fTokenAddr.isContract(), "fToken address is not a contract");
        // Make sure base asset it 3crv:
        require(
            address(baseAsset) == address(THREE_CRV),
            "Base asset is not 3crv"
        );
        // Check that asset and fToken are compatible
        if (_asset == DAI) {
            require(_fTokenAddr == F_DAI, "!fDAI");
        } else if (_asset == USDC) {
            require(_fTokenAddr == F_USDC, "!fUSDC");
        } else if (_asset == USDT) {
            require(_fTokenAddr == F_USDT, "!fUSDT");
        } else {
            revert FluxIntegrationErrors.UknownAssetPair();
        }

        _underlyingAsset = ERC20(_asset);
        _fToken = IFluxToken(_fTokenAddr);
        // Approve underlying asset to be used by 3pool
        _underlyingAsset.safeApprove(address(THREE_POOL), type(uint256).max);
        // Approve underlying asset to be used by fToken contract
        _underlyingAsset.safeApprove(address(_fToken), type(uint256).max);
        // Approve 3crv to be used by gvault
        THREE_CRV.approve(address(_gVault), type(uint256).max);
        owner = msg.sender;

        underlyingAssetIndex = _asset == DAI ? DAI_INDEX : _asset == USDC
            ? USDC_INDEX
            : USDT_INDEX;
    }

    /*//////////////////////////////////////////////////////////////
                        VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

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
    /// @notice Invest loose assets into current position and mint fTokens
    /// @dev Reverts if minting function returns non-zero value
    /// @param _credit Amount available to invest denominated in 3crv
    function _invest(uint256 _credit) internal override returns (uint256) {
        // First, we need to get back underlying asset from 3pool
        THREE_POOL.remove_liquidity_one_coin(
            _credit,
            int128(int256(underlyingAssetIndex)),
            0
        );
        uint256 underlyingBalance = _underlyingAsset.balanceOf(address(this));
        // Now we can mint fToken
        uint256 success = _fToken.mint(underlyingBalance);
        if (success != 0) revert FluxIntegrationErrors.MintFailed();
        return _credit;
    }

    /// @notice Attempts to remove assets from active position
    /// @param _debt Amount to divest from position denominated in 3crv
    /// @param _slippage ignore slippage as Flux is not AMM
    /// @return amount of assets denominated in 3crv that were divested
    function _divest(
        uint256 _debt,
        bool _slippage
    ) internal override returns (uint256) {
        // Convert _debt denominated in 3crv to underlying token first, then to fToken
        uint256 estimatedUnderlyingValue = THREE_POOL.calc_withdraw_one_coin(
            _debt,
            int128(int256(underlyingAssetIndex))
        );
        // Now convert to fToken
        uint256 fTokensToRedeem = (estimatedUnderlyingValue * DECIMALS_FACTOR) /
            _fToken.exchangeRateStored();
        uint256 success = _fToken.redeem(fTokensToRedeem);
        if (success != 0) revert FluxIntegrationErrors.RedeemFailed();

        uint256[3] memory _amounts;
        // Now we need to swap redeemed underlying asset to 3crv
        // Balance to withdraw is calculated as difference between current balance and balance snapshot
        _amounts[underlyingAssetIndex] = _underlyingAsset.balanceOf(
            address(this)
        );
        // Add liquidity to 3pool
        THREE_POOL.add_liquidity(_amounts, 0);
        return baseAsset.balanceOf(address(this));
    }

    /// @notice Remove all assets from active position
    /// @param _slippage ignore slippage as Flux is not AMM
    /// @return amount of assets denominated in 3crv that were divested
    function _divestAll(bool _slippage) internal override returns (uint256) {
        uint256 balance = _fToken.balanceOf(address(this));
        uint256 success = _fToken.redeem(balance);
        if (success != 0) revert FluxIntegrationErrors.RedeemFailed();
        // Convert redeemed underlying asset to 3crv
        uint256[3] memory _amounts;
        _amounts[underlyingAssetIndex] = _underlyingAsset.balanceOf(
            address(this)
        );
        THREE_POOL.add_liquidity(_amounts, 0);
        if (_slippage) {
            // Compare current debt to debt snapshot and check difference slippage,
            // Then, if slippage is too high, revert
            uint256 debt = _gVault.getStrategyDebt();
            if (debt > baseAsset.balanceOf(address(this))) {
                // Calculate slippage in basis points
                uint256 slippage = ((debt -
                    baseAsset.balanceOf(address(this))) * BASIS_POINTS) / debt;
                console2.log("Slippage: %s", slippage);
                console2.log("debt: %s", debt);
                console2.log("3crv balance: %s", baseAsset.balanceOf(address(this)));
                if (slippage > baseSlippage) {
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
        // Get fToken balance in fToken
        uint256 _balanceUnderlyingPosition = (_fToken.balanceOf(address(this)) *
            _fToken.exchangeRateStored()) / DECIMALS_FACTOR;

        // "Simulate" deposit into 3pool to get amount of 3crv we can potentially get
        _amounts[underlyingAssetIndex] = _balanceUnderlyingPosition;
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
