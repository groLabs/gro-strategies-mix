// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./BaseFixture.t.sol";
import "../src/interfaces/ICurve3Pool.sol";
import {GenericStrategyErrors} from "../src/BaseStrategy.sol";
import {FluxStrategy} from "../src/FluxStrategy.sol";

/// @title Flux Strategy Integration Tests
contract TestFluxStrategy is BaseFixture {
    FluxStrategy public daiStrategy;
    FluxStrategy public usdcStrategy;
    FluxStrategy public usdtStrategy;
    uint256 public constant STRATEGY_SHARE = 10 ** 4 / uint256(3);

    /*//////////////////////////////////////////////////////////////
                        Helper functions and setup
    //////////////////////////////////////////////////////////////*/
    function convert3CrvToUnderlying(
        uint256 amount,
        int128 tokenIx
    ) internal returns (uint256) {
        return ICurve3Pool(THREE_POOL).calc_withdraw_one_coin(amount, tokenIx);
    }

    function setUp() public override {
        super.setUp();
        daiStrategy = new FluxStrategy(
            address(gVault),
            address(DAI),
            address(F_DAI)
        );
        usdcStrategy = new FluxStrategy(
            address(gVault),
            address(USDC),
            address(F_USDC)
        );
        usdtStrategy = new FluxStrategy(
            address(gVault),
            address(USDT),
            address(F_USDT)
        );
        daiStrategy.setKeeper(address(this));
        usdcStrategy.setKeeper(address(this));
        usdtStrategy.setKeeper(address(this));
        gVault.addStrategy(address(daiStrategy), STRATEGY_SHARE);
        gVault.addStrategy(address(usdcStrategy), STRATEGY_SHARE);
        gVault.addStrategy(address(usdtStrategy), STRATEGY_SHARE);
    }

    /*//////////////////////////////////////////////////////////////
                        Strategy Setup
    //////////////////////////////////////////////////////////////*/
    /// @notice Basic test to ensure the fixture is working
    function testBasicSetup() public {
        assertEq(daiStrategy.asset(), address(DAI));
        assertEq(usdcStrategy.asset(), address(USDC));
        assertEq(usdtStrategy.asset(), address(USDT));

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
            ERC20(DAI).allowance(address(daiStrategy), address(F_DAI)),
            type(uint256).max
        );
        assertEq(
            ERC20(USDC).allowance(address(usdcStrategy), address(F_USDC)),
            type(uint256).max
        );
        assertEq(
            ERC20(USDT).allowance(address(usdtStrategy), address(F_USDT)),
            type(uint256).max
        );

        // Check underlying asset index wrt to 3pool
        assertEq(daiStrategy.underlyingAssetIndex(), 0);
        assertEq(usdcStrategy.underlyingAssetIndex(), 1);
        assertEq(usdtStrategy.underlyingAssetIndex(), 2);

        // Check strategy owner
        assertEq(daiStrategy.owner(), address(this));
    }

    /*//////////////////////////////////////////////////////////////
                        Test Setters
    //////////////////////////////////////////////////////////////*/
    function testSetKeeper() public {
        assertEq(daiStrategy.keepers(alice), false);
        daiStrategy.setKeeper(alice);
        assertEq(daiStrategy.keepers(alice), true);
    }

    function testSetKeeperNotOwner() public {
        vm.startPrank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(GenericStrategyErrors.NotOwner.selector)
        );
        daiStrategy.setKeeper(alice);
    }

    /*//////////////////////////////////////////////////////////////
                        Core logic tests
    //////////////////////////////////////////////////////////////*/
    function testStrategiesBasicHarvest() public {
        // Give 3crv to vault:
        depositIntoVault(address(this), 10_000_000e18, 0);

        assertEq(F_DAI.balanceOf(address(daiStrategy)), 0);
        assertEq(F_USDC.balanceOf(address(usdcStrategy)), 0);
        assertEq(F_USDT.balanceOf(address(usdtStrategy)), 0);
        daiStrategy.runHarvest();
        usdcStrategy.runHarvest();
        usdtStrategy.runHarvest();

        // Make sure tokens are invested into fTokens
        assertGt(F_DAI.balanceOf(address(daiStrategy)), 0);
        assertGt(F_USDC.balanceOf(address(usdcStrategy)), 0);
        assertGt(F_USDT.balanceOf(address(usdtStrategy)), 0);

        // Make sure no loose stablecoins are left in the strategies
        assertEq(DAI.balanceOf(address(daiStrategy)), 0);
        assertEq(USDC.balanceOf(address(usdcStrategy)), 0);
        assertEq(USDT.balanceOf(address(usdtStrategy)), 0);
    }

    function testStrategyHarvestAssetsDAI(uint256 daiDeposit) public {
        // Give 3crv to vault:
        vm.assume(daiDeposit > 100e18);
        vm.assume(daiDeposit < 100_000_000e18);
        depositIntoVault(address(this), daiDeposit, 0);
        uint256 strategyShare = gVault.totalAssets() / uint256(3);
        daiStrategy.runHarvest();

        // Expected ftoken balance would be 3crv converted to DAI and divided by ftoken exchange rate
        uint256 estimatedUnderlyingStable = convert3CrvToUnderlying(
            strategyShare,
            0
        );
        uint256 expectedFTokenBalance = (estimatedUnderlyingStable * 1e18) /
            F_DAI.exchangeRateStored();

        assertApproxEqAbs(
            F_DAI.balanceOf(address(daiStrategy)),
            expectedFTokenBalance,
            1e13
        );
    }

    function testStrategyHarvestAssetsUSDC(uint256 usdcDeposit) public {
        // USDC has 6 decimals
        vm.assume(usdcDeposit > 100e6);
        vm.assume(usdcDeposit < 100_000_000e6);
        depositIntoVault(address(this), usdcDeposit, 1);
        uint256 strategyShare = gVault.totalAssets() / uint256(3);
        usdcStrategy.runHarvest();

        // Expected ftoken balance would be 3crv converted to DAI and divided by ftoken exchange rate
        uint256 estimatedUnderlyingStable = convert3CrvToUnderlying(
            strategyShare,
            1
        );
        uint256 expectedFTokenBalance = (estimatedUnderlyingStable * 1e18) /
            F_USDC.exchangeRateStored();
        assertApproxEqAbs(
            F_USDC.balanceOf(address(usdcStrategy)),
            expectedFTokenBalance,
            1e13
        );
    }

    function testStrategyHarvestAssetsUSDT(uint256 usdtDeposit) public {
        // USDT has 6 decimals
        vm.assume(usdtDeposit > 100e6);
        vm.assume(usdtDeposit < 100_000_000e6);
        depositIntoVault(address(this), usdtDeposit, 2);
        uint256 strategyShare = gVault.totalAssets() / uint256(3);
        usdtStrategy.runHarvest();

        // Expected ftoken balance would be 3crv converted to DAI and divided by ftoken exchange rate
        uint256 estimatedUnderlyingStable = convert3CrvToUnderlying(
            strategyShare,
            2
        );
        uint256 expectedFTokenBalance = (estimatedUnderlyingStable * 1e18) /
            F_USDT.exchangeRateStored();
        assertApproxEqAbs(
            F_USDT.balanceOf(address(usdtStrategy)),
            expectedFTokenBalance,
            1e14
        );
    }

    function testStrategyHarvestDAIWithProfit(uint256 daiDeposit) public {
        // Give 3crv to vault:
        vm.assume(daiDeposit > 100e18);
        vm.assume(daiDeposit < 100_000_000e18);
        uint256 exchangeRateSnapshot = F_DAI.exchangeRateStored();
        depositIntoVault(address(this), daiDeposit, 0);

        daiStrategy.runHarvest();
        uint256 initEstimatedAssets = daiStrategy.estimatedTotalAssets();
        // Modify fTOKEN fex rate to simulate profit
        setStorage(
            address(daiStrategy),
            IFluxToken(F_DAI.implementation()).exchangeRateStored.selector,
            address(F_DAI.implementation()),
            exchangeRateSnapshot * 2
        );
        // Run harvest to realize profit
        daiStrategy.runHarvest();

        assertGt(daiStrategy.estimatedTotalAssets(), initEstimatedAssets);
    }

    function testStrategyHarvestUSDCWithProfit(uint256 usdcDeposit) public {
        // USDC has 6 decimals
        vm.assume(usdcDeposit > 100e6);
        vm.assume(usdcDeposit < 100_000_000e6);
        uint256 exchangeRateSnapshot = F_USDC.exchangeRateStored();
        depositIntoVault(address(this), usdcDeposit, 1);
        usdcStrategy.runHarvest();

        uint256 initEstimatedAssets = usdcStrategy.estimatedTotalAssets();
        // Modify fTOKEN fex rate to simulate profit
        setStorage(
            address(usdcStrategy),
            IFluxToken(F_USDC.implementation()).exchangeRateStored.selector,
            address(F_USDC.implementation()),
            exchangeRateSnapshot * 2
        );
        // Run harvest to realize profit
        usdcStrategy.runHarvest();

        assertGt(usdcStrategy.estimatedTotalAssets(), initEstimatedAssets);
    }

    function testStrategyHarvestUSDTWithProfit(uint256 usdtDeposit) public {
        // USDT has 6 decimals
        vm.assume(usdtDeposit > 100e6);
        vm.assume(usdtDeposit < 100_000_000e6);
        uint256 exchangeRateSnapshot = F_USDT.exchangeRateStored();
        depositIntoVault(address(this), usdtDeposit, 1);
        usdtStrategy.runHarvest();

        uint256 initEstimatedAssets = usdtStrategy.estimatedTotalAssets();
        // Modify fTOKEN fex rate to simulate profit
        setStorage(
            address(usdtStrategy),
            IFluxToken(F_USDT.implementation()).exchangeRateStored.selector,
            address(F_USDT.implementation()),
            exchangeRateSnapshot * 2
        );
        // Run harvest to realize profit
        usdtStrategy.runHarvest();

        assertGt(usdtStrategy.estimatedTotalAssets(), initEstimatedAssets);
    }
}
