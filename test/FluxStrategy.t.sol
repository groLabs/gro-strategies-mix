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

        // Check vault address:
        assertEq(daiStrategy.vault(), address(gVault));
        assertEq(usdcStrategy.vault(), address(gVault));
        assertEq(usdtStrategy.vault(), address(gVault));

        // Metapool is 0 as a placeholder:
        assertEq(daiStrategy.getMetaPool(), address(0));
        assertEq(usdcStrategy.getMetaPool(), address(0));
        assertEq(usdtStrategy.getMetaPool(), address(0));

        // Set slippage and check it
        daiStrategy.setPartialDivestSlippage(100);
        assertEq(daiStrategy.partialDivestSlippage(), 100);

        // Set full divest slippage and check it
        daiStrategy.setFullDivestSlippage(1001);
        assertEq(daiStrategy.fullDivestSlippage(), 1001);
    }

    /// @dev strategy can stop loss with stop loss being 0 addr should always return false
    function testCanStopLossZeroAddr() public {
        assertEq(daiStrategy.stopLossLogic(), address(0));
        assertFalse(daiStrategy.canStopLoss());
        assertEq(usdcStrategy.stopLossLogic(), address(0));
        assertFalse(usdcStrategy.canStopLoss());
        assertEq(usdtStrategy.stopLossLogic(), address(0));
        assertFalse(usdtStrategy.canStopLoss());
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

    function testStrategyHarvestDAIWithLossAndWithdraw(
        uint256 daiDeposit
    ) public {
        // Give 3crv to vault:
        vm.assume(daiDeposit > 100e18);
        vm.assume(daiDeposit < 100_000_000e18);
        depositIntoVault(address(alice), daiDeposit, 0);

        daiStrategy.runHarvest();
        uint256 initEstimatedAssets = daiStrategy.estimatedTotalAssets();
        uint256 initVaultAssets = gVault.realizedTotalAssets();
        // Modify fTOKEN fex rate to simulate major loss
        setStorage(
            address(F_DAI),
            DAI.balanceOf.selector,
            address(DAI),
            DAI.balanceOf(address(F_DAI)) / 2
        );
        // Alice withdraws after major loss
        withdrawFromVault(
            alice,
            gVault.convertToShares(gVault.realizedTotalAssets() / 2)
        );
        // Run harvest to realize loss
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
                        WIthdraw logic tests
    //////////////////////////////////////////////////////////////*/
    /// @dev Case to check all 3crv is withdrewn from strategy in case all funds are pulled out
    function testWithdrawAllFromStrategy(uint256 daiDeposit) public {
        vm.assume(daiDeposit > 100e18);
        vm.assume(daiDeposit < 100_000_000e18);
        depositIntoVault(alice, daiDeposit, 0);

        daiStrategy.runHarvest();
        // Now, after assets are pulled in from harvest, user wants to withdraw everything they deposited,
        // Which should result in 0 assets left in the strategy
        withdrawFromVault(
            alice,
            gVault.convertToShares(gVault.realizedTotalAssets())
        );

        assertEq(daiStrategy.estimatedTotalAssets(), 0);
        // Make sure other strategies have no assets left
        assertEq(usdcStrategy.estimatedTotalAssets(), 0);
        assertEq(usdtStrategy.estimatedTotalAssets(), 0);
        // Make sure nothing left in vault:
        assertEq(gVault.realizedTotalAssets(), 0);
    }

    function testWithdrawPartiallyFromStrategy(uint256 daiDeposit) public {
        vm.assume(daiDeposit > 100e18);
        vm.assume(daiDeposit < 100_000_000e18);
        depositIntoVault(alice, daiDeposit, 0);

        uint256 vaultAssetsSnapshot = gVault.realizedTotalAssets();
        daiStrategy.runHarvest();
        // Withdraw half of the assets
        withdrawFromVault(
            alice,
            gVault.convertToShares(gVault.realizedTotalAssets() / 2)
        );
        // Make sure half of the assets are taken out from vault
        assertApproxEqAbs(
            gVault.realizedTotalAssets(),
            vaultAssetsSnapshot / 2,
            1e13
        );
    }

    /// @dev Case when profit is realized and user withdraws and gets profit
    function testWithdrawWithProfitMultipleDepositors(
        uint256 daiDeposit
    ) public {
        vm.assume(daiDeposit > 100e18);
        vm.assume(daiDeposit < 1_000_000e18);
        depositIntoVault(alice, daiDeposit, 0);
        uint256 alice3crvSnapshot = THREE_POOL_TOKEN.balanceOf(alice);
        depositIntoVault(bob, daiDeposit, 0);
        daiStrategy.runHarvest();
        usdcStrategy.runHarvest();
        usdtStrategy.runHarvest();
        // Modify fTOKEN fex rate to simulate profit
        setStorage(
            address(F_DAI),
            DAI.balanceOf.selector,
            address(DAI),
            DAI.balanceOf(address(F_DAI)) * 100
        );
        withdrawFromVault(alice, gVault.balanceOf(alice) / 2);
        // Make sure alice has half of the assets back plus profit
        assertGt(THREE_POOL_TOKEN.balanceOf(alice), alice3crvSnapshot);
    }

    /// @dev Case when profit is realized and user withdraws and gets profit
    function testWithdrawWithLossMultipleDepositors(uint256 daiDeposit) public {
        vm.assume(daiDeposit > 100e18);
        vm.assume(daiDeposit < 1_000_000e18);
        depositIntoVault(alice, daiDeposit, 0);
        // Consider that alice DAI balance is set to max in genThreeCrv() function
        uint256 alice3crvSnapshot = THREE_POOL_TOKEN.balanceOf(alice);

        depositIntoVault(bob, daiDeposit, 0);
        daiStrategy.runHarvest();
        usdcStrategy.runHarvest();
        usdtStrategy.runHarvest();
        // Modify fTOKEN fex rate to simulate loss
        setStorage(
            address(F_DAI),
            DAI.balanceOf.selector,
            address(DAI),
            DAI.balanceOf(address(F_DAI)) / 2
        );
        withdrawFromVault(alice, gVault.balanceOf(alice) / 2);
        assertGt(DAI.balanceOf(alice), 0);
        // Make sure alice has her assets back minus loss
        assertGt(THREE_POOL_TOKEN.balanceOf(alice), alice3crvSnapshot);
    }

    /// @dev Invariant: Should always pull from strategy balance instead of divesting from Flux
    function testWithdrawDirectlyFromStrategyBalance(
        uint256 usdcDeposit
    ) public {
        vm.assume(usdcDeposit > 100e6);
        vm.assume(usdcDeposit < 1_000_000e6);
        depositIntoVault(alice, usdcDeposit, 1);
        uint256 aliceUSDCSnapshot = USDC.balanceOf(alice);
        uint256 alice3crvSnapshot = THREE_POOL_TOKEN.balanceOf(alice);
        assertEq(aliceUSDCSnapshot, type(uint256).max - usdcDeposit);

        depositIntoVault(bob, usdcDeposit, 1);
        // Harvest all strategies to pull in assets from vault
        daiStrategy.runHarvest();
        usdcStrategy.runHarvest();
        usdtStrategy.runHarvest();

        // Make fusdc snapshot
        uint256 fusdcSnapshot = F_USDC.balanceOf(address(usdcStrategy));

        // Give strategy some loose 3crv token
        setStorage(
            address(usdcStrategy),
            THREE_POOL_TOKEN.balanceOf.selector,
            address(THREE_POOL_TOKEN),
            100_000_000e18
        );
        withdrawFromVault(alice, gVault.balanceOf(alice));
        // Make sure fusdc balance is the same as 3crv is withdrawn from strategy loose balance
        assertEq(F_USDC.balanceOf(address(usdcStrategy)), fusdcSnapshot);
        // Make sure alice has 3crv back
        assertGt(THREE_POOL_TOKEN.balanceOf(alice), alice3crvSnapshot);
    }

    function testStrategyWithdrawRevertIfCallerIsNotVault() public {
        vm.startPrank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(GenericStrategyErrors.NotVault.selector)
        );
        daiStrategy.withdraw(0);
        vm.expectRevert(
            abi.encodeWithSelector(GenericStrategyErrors.NotVault.selector)
        );
        usdcStrategy.withdraw(0);
        vm.expectRevert(
            abi.encodeWithSelector(GenericStrategyErrors.NotVault.selector)
        );
        usdtStrategy.withdraw(0);
    }

    /*//////////////////////////////////////////////////////////////
                        View function tests
    //////////////////////////////////////////////////////////////*/
    /// @dev case when there is profit to harvest and enough time passed
    function testCanHarvestHappyProfit(uint256 daiDeposit) public {
        vm.assume(daiDeposit > 10000e18);
        vm.assume(daiDeposit < 100_000_000e18);
        depositIntoVault(alice, daiDeposit, 0);
        daiStrategy.runHarvest();

        // Modify fTOKEN fex rate to simulate massive profit to make sure can harvest is true
        setStorage(
            address(F_DAI),
            DAI.balanceOf.selector,
            address(DAI),
            DAI.balanceOf(address(F_DAI)) * 100
        );
        // can harvest should be false as not enough time has passed
        vm.warp(block.timestamp + daiStrategy.MIN_REPORT_DELAY() + 1);
        assertTrue(daiStrategy.canHarvest());
    }

    /// @dev case when there is loss to harvest and enough time passed
    function testCanHarvestHappyLoss(uint256 daiDeposit) public {
        vm.assume(daiDeposit > 200_000e18);
        vm.assume(daiDeposit < 100_000_000e18);
        depositIntoVault(alice, daiDeposit, 0);
        daiStrategy.runHarvest();

        // Modify fTOKEN fex rate to simulate massive loss to make sure can harvest is true
        setStorage(address(F_DAI), DAI.balanceOf.selector, address(DAI), 0);
        // can harvest should be false as not enough time has passed
        vm.warp(block.timestamp + daiStrategy.MIN_REPORT_DELAY() + 1);
        assertTrue(daiStrategy.canHarvest());
    }

    /// @dev Should always harvest if too much time passed
    function testCanHarvestTooMuchTimePassed(uint256 daiDeposit) public {
        vm.assume(daiDeposit > 100e18);
        vm.assume(daiDeposit < 100_000_000e18);
        depositIntoVault(alice, daiDeposit, 0);
        daiStrategy.runHarvest();

        assertFalse(daiStrategy.canHarvest());
        vm.warp(block.timestamp + daiStrategy.MAX_REPORT_DELAY() + 1);
        assertTrue(daiStrategy.canHarvest());
    }

    function testCanHarvestNotEnoughTimePassed(uint256 daiDeposit) public {
        vm.assume(daiDeposit > 100e18);
        vm.assume(daiDeposit < 100_000_000e18);
        depositIntoVault(alice, daiDeposit, 0);
        daiStrategy.runHarvest();

        // Modify fTOKEN fex rate to simulate profit
        setStorage(
            address(F_DAI),
            DAI.balanceOf.selector,
            address(DAI),
            DAI.balanceOf(address(F_DAI)) * 10
        );
        // can harvest should be false as not enough time has passed
        assertFalse(daiStrategy.canHarvest());
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

    /// @dev Slippage can happen when pool is imbalanced and strategy(on divest) will try to add liquidity
    /// to the pool in the most popular asset in 3crv, which will result in slippage
    function testDAIShouldPullOutSlippageRevert(uint256 daiDeposit) public {
        vm.assume(daiDeposit > 100e18);
        vm.assume(daiDeposit < 100_000_000_000e18);
        depositIntoVault(address(this), daiDeposit, 0);
        daiStrategy.runHarvest();

        // Create imbalance in pool by depositing more DAI
        genThreeCrv(100_000_000_000_000e18, address(this), 0);
        vm.expectRevert(
            abi.encodeWithSelector(
                GenericStrategyErrors.SlippageProtection.selector
            )
        );
        daiStrategy.stopLoss();
    }

    //    function testDAIHarvestDivestAndSlippageRevert(uint256 daiDeposit) public {
    //        vm.assume(daiDeposit > 100e18);
    //        vm.assume(daiDeposit < 100_000_000_000e18);
    //        // Set debt ratios as 20% for each strategy
    //        gVault.setDebtRatio(address(daiStrategy), 2000);
    //        gVault.setDebtRatio(address(usdcStrategy), 2000);
    //        gVault.setDebtRatio(address(usdtStrategy), 2000);
    //        depositIntoVault(address(this), daiDeposit, 0);
    //
    //        daiStrategy.runHarvest();
    //        usdcStrategy.runHarvest();
    //        usdtStrategy.runHarvest();
    //        // Withdraw from vault to create debt in strategies
    //        withdrawFromVault(address(this), gVault.balanceOf(address(this)) / 5);
    //        // Create imbalance in pool by depositing more DAI
    //        genThreeCrv(100_000_000_000e18, address(this), 0);
    //        // Modify fTOKEN fex rate to simulate profit
    //        setStorage(
    //            address(F_DAI),
    //            DAI.balanceOf.selector,
    //            address(DAI),
    //            DAI.balanceOf(address(F_DAI)) * 10
    //        );
    //        vm.expectRevert(
    //            abi.encodeWithSelector(
    //                GenericStrategyErrors.SlippageProtection.selector
    //            )
    //        );
    //        daiStrategy.runHarvest();
    //    }

    function testCanResumeAfterStopLoss(uint256 daiDeposit) public {
        vm.assume(daiDeposit > 100e18);
        vm.assume(daiDeposit < 100_000_000e18);
        depositIntoVault(address(this), daiDeposit, 0);
        daiStrategy.runHarvest();
        assertEq(THREE_POOL_TOKEN.balanceOf(address(daiStrategy)), 0);
        // Now run stop loss
        daiStrategy.stopLoss();
        // Make sure all assets are pulled out
        assertEq(F_DAI.balanceOf(address(daiStrategy)), 0);
        // Make sure stop loss is active
        assertEq(daiStrategy.stop(), true);

        // Resume now and harvest
        daiStrategy.resume();
        daiStrategy.runHarvest();
        // Check that assets are deposited back
        assertGt(F_DAI.balanceOf(address(daiStrategy)), 0);
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
    /// @dev simulate harvest in emergency mode during harvest
    function testHarvestEmergencyLoss(uint256 daiDeposit) public {
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

    /// @dev same thing as above just to make sure we can handle profit in emergency mode
    function testHarvestEmergencyProfit(uint256 daiDeposit) public {
        // Give 3crv to vault:
        vm.assume(daiDeposit > 100e18);
        vm.assume(daiDeposit < 100_000_000e18);
        depositIntoVault(address(this), daiDeposit, 0);
        daiStrategy.runHarvest();

        assertEq(THREE_POOL_TOKEN.balanceOf(address(daiStrategy)), 0);

        // Set emergency now and harvest
        daiStrategy.setEmergencyMode();
        // Modify fTOKEN fex rate to simulate profit
        setStorage(
            address(F_DAI),
            DAI.balanceOf.selector,
            address(DAI),
            DAI.balanceOf(address(F_DAI)) * 10
        );
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
