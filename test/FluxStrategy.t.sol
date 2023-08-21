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
    uint256 internal constant MIN_REPORT_DELAY = 172800;

    /*//////////////////////////////////////////////////////////////
                        Helper functions and setup
    //////////////////////////////////////////////////////////////*/
    function convert3CrvToUnderlying(
        uint256 amount,
        int128 tokenIx
    ) internal view returns (uint256) {
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
        depositIntoVault(address(this), daiDeposit, 0);

        daiStrategy.runHarvest();
        uint256 initEstimatedAssets = daiStrategy.estimatedTotalAssets();
        // Modify fTOKEN fex rate to simulate profit
        setStorage(
            address(F_DAI),
            DAI.balanceOf.selector,
            address(DAI),
            DAI.balanceOf(address(F_DAI)) * 2
        );
        // Run harvest to realize profit
        daiStrategy.runHarvest();

        assertGt(daiStrategy.estimatedTotalAssets(), initEstimatedAssets);
    }

    function testStrategyHarvestUSDCWithProfit(uint256 usdcDeposit) public {
        // USDC has 6 decimals
        vm.assume(usdcDeposit > 100e6);
        vm.assume(usdcDeposit < 100_000_000e6);
        depositIntoVault(address(this), usdcDeposit, 1);
        usdcStrategy.runHarvest();

        uint256 initEstimatedAssets = usdcStrategy.estimatedTotalAssets();
        // Modify fTOKEN fex rate to simulate profit
        setStorage(
            address(F_USDC),
            USDC.balanceOf.selector,
            address(USDC),
            USDC.balanceOf(address(F_USDC)) * 2
        );
        // Run harvest to realize profit
        usdcStrategy.runHarvest();

        assertGt(usdcStrategy.estimatedTotalAssets(), initEstimatedAssets);
    }

    function testStrategyHarvestUSDTWithProfit(uint256 usdtDeposit) public {
        // USDT has 6 decimals
        vm.assume(usdtDeposit > 100e6);
        vm.assume(usdtDeposit < 100_000_000e6);
        depositIntoVault(address(this), usdtDeposit, 2);
        usdtStrategy.runHarvest();

        uint256 initEstimatedAssets = usdtStrategy.estimatedTotalAssets();
        // Modify fTOKEN fex rate to simulate profit
        setStorage(
            address(F_USDT),
            USDT.balanceOf.selector,
            address(USDT),
            USDT.balanceOf(address(F_USDT)) * 2
        );
        // Run harvest to realize profit
        usdtStrategy.runHarvest();

        assertGt(usdtStrategy.estimatedTotalAssets(), initEstimatedAssets);
    }

    function testStrategyHarvestDAIWithLoss(uint256 daiDeposit) public {
        // Give 3crv to vault:
        vm.assume(daiDeposit > 100e18);
        vm.assume(daiDeposit < 100_000_000e18);
        depositIntoVault(address(this), daiDeposit, 0);

        daiStrategy.runHarvest();
        uint256 initEstimatedAssets = daiStrategy.estimatedTotalAssets();
        uint256 initVaultAssets = gVault.realizedTotalAssets();
        // Modify fTOKEN fex rate to simulate major loss
        setStorage(address(F_DAI), DAI.balanceOf.selector, address(DAI), 0);
        // Run harvest to realize profit
        daiStrategy.runHarvest();

        assertGt(initEstimatedAssets, daiStrategy.estimatedTotalAssets());
        assertGt(initVaultAssets, gVault.realizedTotalAssets());
    }

    function testStrategyHarvestUSDCWithLoss(uint256 usdcDeposit) public {
        // USDC has 6 decimals
        vm.assume(usdcDeposit > 100e6);
        vm.assume(usdcDeposit < 100_000_000e6);
        depositIntoVault(address(this), usdcDeposit, 1);
        usdcStrategy.runHarvest();

        uint256 initEstimatedAssets = usdcStrategy.estimatedTotalAssets();
        uint256 initVaultAssets = gVault.realizedTotalAssets();
        // Modify fTOKEN fex rate to simulate profit
        setStorage(address(F_USDC), USDC.balanceOf.selector, address(USDC), 0);
        // Run harvest to realize profit
        usdcStrategy.runHarvest();

        assertGt(initEstimatedAssets, usdcStrategy.estimatedTotalAssets());
        assertGt(initVaultAssets, gVault.realizedTotalAssets());
    }

    function testStrategyHarvestUSDTWithLoss(uint256 usdtDeposit) public {
        // USDT has 6 decimals
        vm.assume(usdtDeposit > 100e6);
        vm.assume(usdtDeposit < 100_000_000e6);
        depositIntoVault(address(this), usdtDeposit, 2);
        usdtStrategy.runHarvest();

        uint256 initEstimatedAssets = usdtStrategy.estimatedTotalAssets();
        uint256 initVaultAssets = gVault.realizedTotalAssets();
        // Modify fTOKEN fex rate to simulate profit
        setStorage(address(F_USDT), USDT.balanceOf.selector, address(USDT), 0);
        // Run harvest to realize profit
        usdtStrategy.runHarvest();

        assertGt(initEstimatedAssets, usdtStrategy.estimatedTotalAssets());
        assertGt(initVaultAssets, gVault.realizedTotalAssets());
    }

    /*//////////////////////////////////////////////////////////////
                        Stop Loss
    //////////////////////////////////////////////////////////////*/
    function testDAIShouldPullOutDuringStopLoss(uint256 daiDeposit) public {
        vm.assume(daiDeposit > 100e18);
        vm.assume(daiDeposit < 100_000_000e18);
        depositIntoVault(address(this), daiDeposit, 0);
        daiStrategy.runHarvest();
        assertEq(THREE_POOL_TOKEN.balanceOf(address(daiStrategy)), 0);
        // Now run stop loss
        daiStrategy.stopLoss();

        // Make sure all assets are pulled out
        assertGt(THREE_POOL_TOKEN.balanceOf(address(daiStrategy)), 0);
        assertEq(DAI.balanceOf(address(daiStrategy)), 0);
        assertEq(F_DAI.balanceOf(address(daiStrategy)), 0);
        // Make sure can't harvest anymore:
        vm.expectRevert(
            abi.encodeWithSelector(GenericStrategyErrors.Stopped.selector)
        );
        daiStrategy.runHarvest();
    }

    function testUSDCShouldPullOutDuringStopLoss(uint256 usdcDeposit) public {
        vm.assume(usdcDeposit > 100e6);
        vm.assume(usdcDeposit < 100_000_000e6);
        depositIntoVault(address(this), usdcDeposit, 1);
        usdcStrategy.runHarvest();
        assertEq(THREE_POOL_TOKEN.balanceOf(address(usdcStrategy)), 0);
        // Now run stop loss
        usdcStrategy.stopLoss();

        // Make sure all assets are pulled out
        assertGt(THREE_POOL_TOKEN.balanceOf(address(usdcStrategy)), 0);
        assertEq(USDC.balanceOf(address(usdcStrategy)), 0);
        assertEq(F_USDC.balanceOf(address(usdcStrategy)), 0);
        // Make sure can't harvest anymore:
        vm.expectRevert(
            abi.encodeWithSelector(GenericStrategyErrors.Stopped.selector)
        );
        usdcStrategy.runHarvest();
    }

    function testUSDTShouldPullOutDuringStopLoss(uint256 usdtDeposit) public {
        vm.assume(usdtDeposit > 100e6);
        vm.assume(usdtDeposit < 100_000_000e6);
        depositIntoVault(address(this), usdtDeposit, 2);
        usdtStrategy.runHarvest();
        assertEq(THREE_POOL_TOKEN.balanceOf(address(usdtStrategy)), 0);
        // Now run stop loss
        usdtStrategy.stopLoss();

        // Make sure all assets are pulled out
        assertGt(THREE_POOL_TOKEN.balanceOf(address(usdtStrategy)), 0);
        assertEq(USDT.balanceOf(address(usdtStrategy)), 0);
        assertEq(F_USDT.balanceOf(address(usdtStrategy)), 0);
        // Make sure can't harvest anymore:
        vm.expectRevert(
            abi.encodeWithSelector(GenericStrategyErrors.Stopped.selector)
        );
        usdtStrategy.runHarvest();
    }

    /*//////////////////////////////////////////////////////////////
                        Emergency Mode
    //////////////////////////////////////////////////////////////*/
    function testHarvestEmergency(uint256 daiDeposit) public {
        // Give 3crv to vault:
        vm.assume(daiDeposit > 100e18);
        vm.assume(daiDeposit < 100_000_000e18);
        depositIntoVault(address(this), daiDeposit, 0);
        daiStrategy.runHarvest();

        assertEq(THREE_POOL_TOKEN.balanceOf(address(daiStrategy)), 0);

        // Set emergency now and harvest
        daiStrategy.setEmergencyMode();
        daiStrategy.runHarvest();

        // Make sure all assets were pulled out
        assertEq(THREE_POOL_TOKEN.balanceOf(address(daiStrategy)), 0);
        assertEq(USDT.balanceOf(address(daiStrategy)), 0);
        assertEq(F_USDT.balanceOf(address(daiStrategy)), 0);
        // Make sure all 3crv was pulled out and is in the vault
        assertEq(
            THREE_POOL_TOKEN.balanceOf(address(gVault)),
            gVault.totalAssets()
        );
    }
}
