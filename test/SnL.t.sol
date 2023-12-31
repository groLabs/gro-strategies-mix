// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./BaseFixture.t.sol";
import "../src/interfaces/ICurve3Pool.sol";
import {GenericStrategyErrors} from "../src/BaseStrategy.sol";
import {FluxStrategy} from "../src/FluxStrategy.sol";
import {StopLoss} from "../src/StopLoss.sol";

/// @title Flux Strategy Integration Tests
contract TestFluxSnL is BaseFixture {
    FluxStrategy public daiStrategy;
    FluxStrategy public usdcStrategy;
    FluxStrategy public usdtStrategy;

    StopLoss public snl;
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

        // Add SnL to each strategy
        snl = new StopLoss(address(gVault));
        daiStrategy.setStopLossLogic(address(snl));
        usdcStrategy.setStopLossLogic(address(snl));
        usdtStrategy.setStopLossLogic(address(snl));
    }

    function testSetInvalidSnL() public {
        vm.expectRevert("Stop loss address is not a contract");
        daiStrategy.setStopLossLogic(address(0));
    }

    function testSetSnLNotOwner() public {
        vm.startPrank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(GenericStrategyErrors.NotOwner.selector)
        );
        daiStrategy.setStopLossLogic(address(snl));
        vm.stopPrank();
    }

    function testSetValidSnL() public {
        StopLoss newSnl = new StopLoss(address(gVault));
        daiStrategy.setStopLossLogic(address(newSnl));
        assertEq(daiStrategy.stopLossLogic(), address(newSnl));
    }

    function testSetSnlTrheshold() public {
        snl.setSnlThreshold(100);
        assertEq(snl.snLThreshold(), 100);
    }

    function testSimpleSnLProfitScenarioDAI(uint256 daiDeposit) public {
        vm.assume(daiDeposit > 100e18);
        vm.assume(daiDeposit < 100_000_000e18);
        depositIntoVault(address(this), daiDeposit, 0);

        daiStrategy.runHarvest();
        // Modify fTOKEN fex rate to simulate profit
        setStorage(
            address(F_DAI),
            DAI.balanceOf.selector,
            address(DAI),
            DAI.balanceOf(address(F_DAI)) * 2
        );
        // No stop loss should be triggered with profits
        assertFalse(daiStrategy.canStopLoss());
    }

    function testSimpleSnLLossScenarioDAI(uint256 daiDeposit) public {
        vm.assume(daiDeposit > 100e18);
        vm.assume(daiDeposit < 100_000_000e18);
        depositIntoVault(address(this), daiDeposit, 0);

        daiStrategy.runHarvest();
        // Modify fTOKEN fex rate to simulate major loss
        setStorage(address(F_DAI), DAI.balanceOf.selector, address(DAI), 0);
        // stop loss should be triggered with loss
        assertTrue(daiStrategy.canStopLoss());
    }

    function testSimpleSnLLossScenarioUSDC(uint256 usdcDeposit) public {
        vm.assume(usdcDeposit > 100e6);
        vm.assume(usdcDeposit < 100_000_000e6);
        depositIntoVault(address(this), usdcDeposit, 1);
        usdcStrategy.runHarvest();

        // Modify fTOKEN fex rate to simulate loss
        setStorage(address(F_USDC), USDC.balanceOf.selector, address(USDC), 0);
        assertTrue(usdcStrategy.canStopLoss());
    }

    function testSimpleSnLLossScenarioUSDT(uint256 usdtDeposit) public {
        vm.assume(usdtDeposit > 100e6);
        vm.assume(usdtDeposit < 100_000_000e6);
        depositIntoVault(address(this), usdtDeposit, 2);
        usdtStrategy.runHarvest();

        // Modify fTOKEN fex rate to simulate loss
        setStorage(address(F_USDT), USDT.balanceOf.selector, address(USDT), 0);
        assertTrue(usdtStrategy.canStopLoss());
    }
}
