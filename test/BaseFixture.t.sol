// SPDX-License-Identifier: AGPLv3
pragma solidity ^0.8.13;
import "forge-std/Test.sol";
import "../src/external/GVault.sol";
import {FluxStrategy} from "../src/FluxStrategy.sol";
import "./utils.sol";

contract BaseFixture is Test {
    ERC20 public constant THREE_POOL_TOKEN =
        ERC20(address(0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490));

    address public constant THREE_POOL =
        0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7;

    address public constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    address public constant F_USDC = 0x465a5a630482f3abD6d3b84B39B29b07214d19e5;
    address public constant F_DAI = 0xe2bA8693cE7474900A045757fe0efCa900F6530b;
    address public constant F_USDT = 0x81994b9607e06ab3d5cF3AffF9a67374f05F27d7;

    GVault public gVault;
    FluxStrategy public daiStrategy;
    FluxStrategy public usdcStrategy;
    FluxStrategy public usdtStrategy;

    Utils internal utils;

    function setUp() public virtual {
        utils = new Utils();
        gVault = new GVault(THREE_POOL_TOKEN);
        daiStrategy = new FluxStrategy(address(gVault), DAI, F_DAI);
        usdcStrategy = new FluxStrategy(address(gVault), USDC, F_USDC);
        usdtStrategy = new FluxStrategy(address(gVault), USDT, F_USDT);
        gVault.addStrategy(address(daiStrategy), 3333);
        gVault.addStrategy(address(usdcStrategy), 3333);
        gVault.addStrategy(address(usdtStrategy), 3333);
    }

    /// @notice Basic test to ensure the fixture is working
    function testBasicSetup() public {
        assertEq(daiStrategy.asset(), DAI);
        assertEq(usdcStrategy.asset(), USDC);
        assertEq(usdtStrategy.asset(), USDT);

        // Check allowances on 3pool:
        assertEq(
            ERC20(DAI).allowance(address(daiStrategy), THREE_POOL),
            type(uint256).max
        );
        assertEq(
            ERC20(USDC).allowance(address(usdcStrategy), THREE_POOL),
            type(uint256).max
        );
        assertEq(
            ERC20(USDT).allowance(address(usdtStrategy), THREE_POOL),
            type(uint256).max
        );

        // Check allowances on fTokens:
        assertEq(
            ERC20(DAI).allowance(address(daiStrategy), F_DAI),
            type(uint256).max
        );
        assertEq(
            ERC20(USDC).allowance(address(usdcStrategy), F_USDC),
            type(uint256).max
        );
        assertEq(
            ERC20(USDT).allowance(address(usdtStrategy), F_USDT),
            type(uint256).max
        );

        // Check underlying asset index wrt to 3pool
        assertEq(daiStrategy.underlyingAssetIndex(), 0);
        assertEq(usdcStrategy.underlyingAssetIndex(), 1);
        assertEq(usdtStrategy.underlyingAssetIndex(), 2);

        // Check strategy owner
        assertEq(daiStrategy.owner(), address(this));
    }
}
