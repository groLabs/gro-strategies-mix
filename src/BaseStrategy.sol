// SPDX-License-Identifier: AGPLv3
pragma solidity ^0.8.13;

import "./interfaces/IGVault.sol";
import "./interfaces/IStrategy.sol";
import "./interfaces/IStop.sol";
import "../lib/openzeppelin-contracts/contracts/utils/Address.sol";

library StrategyErrors {
    error NotOwner(); // 0x30cd7471
    error NotVault(); // 0x62df0545
    error NotKeeper(); // 0xf512b278
    error Stopped(); // 0x7acc84e3
    error SamePid(); // 0x4eb5bc6d
    error BaseAsset(); // 0xaeca768b
    error LpToken(); // 0xaeca768b
    error LTMinAmountExpected(); // 0x3d93e699
    error ExcessDebtGtThanAssets(); // 0x961696d0
    error LPNotZero(); // 0xe4e07afa
    error SlippageProtection(); // 0x17d431f4
}

abstract contract BaseStrategy is IStrategy {
    using Address for address;
    /*//////////////////////////////////////////////////////////////
                        CONSTANTS & IMMUTABLES
    //////////////////////////////////////////////////////////////*/
    uint256 internal constant MAX_REPORT_DELAY = 604800;
    uint256 internal constant MIN_REPORT_DELAY = 172800;
    uint256 internal constant DEFAULT_DECIMALS_FACTOR = 1E18;

    uint256 internal constant INVESTMENT_BUFFER = 10E18;

    IGVault internal immutable _gVault;
    /*//////////////////////////////////////////////////////////////
                        STORAGE VARIABLES
    //////////////////////////////////////////////////////////////*/
    bool public emergencyMode;
    bool public stop;

    mapping(address => bool) public keepers;

    address public stopLossLogic;
    uint256 public stopLossAttempts;

    uint256 internal profitThreshold = 20_000 * DEFAULT_DECIMALS_FACTOR;
    uint256 internal debtThreshold = 20_000 * DEFAULT_DECIMALS_FACTOR;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    event Harvested(
        uint256 profit,
        uint256 loss,
        uint256 debtRepayment,
        uint256 excessDebt
    );

    constructor(address _vault) {
        require(_vault.isContract(), "Vault address is not a contract");
        _gVault = IGVault(_vault);
    }

    /*//////////////////////////////////////////////////////////////
                        VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

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
    ) internal virtual returns (uint256, uint256, uint256, uint256);
}
