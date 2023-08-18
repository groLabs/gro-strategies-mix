// SPDX-License-Identifier: AGPLv3
pragma solidity ^0.8.13;

/// @dev Interface of the ERC20 standard as defined in the EIP.
/// @dev This includes the optional name, symbol, and decimals metadata.
interface IFluxToken {
    /// @notice Returns the amount of tokens in existence.
    function totalSupply() external view returns (uint256);

    /// @notice Returns the amount of tokens owned by `account`.
    function balanceOf(address account) external view returns (uint256);

    function implementation() external view returns (address);

    /// @notice Moves `amount` tokens from the caller's account to `to`.
    function transfer(address to, uint256 amount) external returns (bool);

    /// @notice Returns the remaining number of tokens that `spender` is allowed
    /// to spend on behalf of `owner`
    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    /// @notice Sets `amount` as the allowance of `spender` over the caller's tokens.
    /// @dev Be aware of front-running risks: https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
    function approve(address spender, uint256 amount) external returns (bool);

    /// @notice Moves `amount` tokens from `from` to `to` using the allowance mechanism.
    /// `amount` is then deducted from the caller's allowance.
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    /// @notice Returns the name of the token.
    function name() external view returns (string memory);

    /// @notice Returns the symbol of the token.
    function symbol() external view returns (string memory);

    /// @notice Returns the decimals places of the token.
    function decimals() external view returns (uint8);

    /// @notice Mint fToken
    /// @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
    function mint(uint256 mintAmount) external returns (uint256);

    /// @notice fToken exchange rate
    function exchangeRateStored() external view returns (uint256);

    /// @notice Redeem fToken for underlying asset
    /// @param redeemTokens The number of cTokens to redeem into underlying
    function redeem(uint256 redeemTokens) external returns (uint256);

    /// @notice Redeem fToken for underlying asset
    /// @param redeemAmount The number of underlying tokens to receive from redeeming cTokens
    function redeemUnderlying(uint256 redeemAmount) external returns (uint256);
}
