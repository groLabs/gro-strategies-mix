// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./BaseFixture.t.sol";
import "../src/interfaces/ICurve3Pool.sol";
import "../src/interfaces/IDSRPot.sol";
import "../src/interfaces/IDSRManager.sol";
import "../src/interfaces/ICurve3Pool.sol";
import {GenericStrategyErrors} from "../src/BaseStrategy.sol";
import {DSRStrategy} from "../src/DSRStrategy.sol";

/// @title DSR Strategy Integration Tests
contract TestDSRStrategy is BaseFixture {
    DSRStrategy public strategy;
    uint256 public constant STRATEGY_SHARE = 10000;

    IDSRManager public constant DSR_MANAGER =
        IDSRManager(0x373238337Bfe1146fb49989fc222523f83081dDb);
    IDSRPot public constant POT =
        IDSRPot(0x197E90f9FAD81970bA7976f33CbD77088E5D7cf7);

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
        strategy = new DSRStrategy(address(gVault));
        strategy.setKeeper(address(this));
        gVault.addStrategy(address(strategy), STRATEGY_SHARE);
    }

    function testBasicSetupDSR() public {
        assertEq(strategy.asset(), address(DAI));

        // Check allowances on 3pool:
        assertEq(
            ERC20(DAI).allowance(address(strategy), THREE_POOL),
            type(uint256).max
        );

        // Check strategy owner
        assertEq(strategy.owner(), address(this));

        // Check vault address:
        assertEq(strategy.vault(), address(gVault));

        // Metapool is 0 as a placeholder:
        assertEq(strategy.getMetaPool(), address(0));

        // Set slippage and check it
        strategy.setPartialDivestSlippage(100);
        assertEq(strategy.partialDivestSlippage(), 100);

        // Set full divest slippage and check it
        strategy.setFullDivestSlippage(1001);
        assertEq(strategy.fullDivestSlippage(), 1001);
    }

    /*//////////////////////////////////////////////////////////////
                        Test Setters
    //////////////////////////////////////////////////////////////*/
    function testSetKeeper() public {
        assertEq(strategy.keepers(alice), false);
        strategy.setKeeper(alice);
        assertEq(strategy.keepers(alice), true);
    }

    function testSetKeeperNotOwner() public {
        vm.startPrank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(GenericStrategyErrors.NotOwner.selector)
        );
        strategy.setKeeper(alice);
    }

    /*//////////////////////////////////////////////////////////////
                        Core logic tests
    //////////////////////////////////////////////////////////////*/

    function testStrategyBasicHarvest(uint256 daiDeposit) public {
        vm.assume(daiDeposit > 100e18);
        vm.assume(daiDeposit < 100_000_000e18);
        // Give 3crv to vault:
        depositIntoVault(address(this), daiDeposit, 0);

        // Make sure strategy has zero in the pot:
        assertEq(DSR_MANAGER.pieOf(address(strategy)), 0);
        strategy.runHarvest();
        // Make sure tokens are invested into fTokens
        assertGt(DSR_MANAGER.pieOf(address(strategy)), 0);
        // Check estimated total assets, calculate % difference between estimated and actual
        assertGt(strategy.estimatedTotalAssets(), 0);
    }
}
