// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./BaseFixture.t.sol";
import {GenericStrategyErrors} from "../src/BaseStrategy.sol";
import {FluxStrategy} from "../src/FluxStrategy.sol";

/// @title Flux Strategy Integration Tests
contract TestFluxStrategy is BaseFixture {
    FluxStrategy public daiStrategy;
    FluxStrategy public usdcStrategy;
    FluxStrategy public usdtStrategy;

    /*//////////////////////////////////////////////////////////////
                        Helper functions and setup
    //////////////////////////////////////////////////////////////*/

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
        gVault.addStrategy(address(daiStrategy), 3333);
        gVault.addStrategy(address(usdcStrategy), 3333);
        gVault.addStrategy(address(usdtStrategy), 3333);
        // Give 3crv to vault:
        depositIntoVault(address(this), 10_000_000e18);
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
        // Make sure 3crv is no 0 in the vault
        assertGt(THREE_POOL_TOKEN.balanceOf(address(gVault)), 0);
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
}
