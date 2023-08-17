// SPDX-License-Identifier: AGPLv3
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/external/GVault.sol";
import "../src/interfaces/ICurve3Pool.sol";
import {ERC20} from "../lib/solmate/src/tokens/ERC20.sol";
import {FluxStrategy} from "../src/FluxStrategy.sol";
import "./utils.sol";
import {SafeTransferLib} from "../lib/solmate/src/utils/SafeTransferLib.sol";

contract BaseFixture is Test {
    using stdStorage for StdStorage;
    using SafeTransferLib for ERC20;
    ERC20 public constant THREE_POOL_TOKEN =
        ERC20(address(0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490));

    address public constant THREE_POOL =
        0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7;

    ERC20 public constant DAI =
        ERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    ERC20 public constant USDC =
        ERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    ERC20 public constant USDT =
        ERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);

    ERC20 public constant F_USDC =
        ERC20(0x465a5a630482f3abD6d3b84B39B29b07214d19e5);
    ERC20 public constant F_DAI =
        ERC20(0xe2bA8693cE7474900A045757fe0efCa900F6530b);
    ERC20 public constant F_USDT =
        ERC20(0x81994b9607e06ab3d5cF3AffF9a67374f05F27d7);

    GVault public gVault;
    FluxStrategy public daiStrategy;
    FluxStrategy public usdcStrategy;
    FluxStrategy public usdtStrategy;

    Utils internal utils;

    function setUp() public virtual {
        utils = new Utils();
        gVault = new GVault(THREE_POOL_TOKEN);
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
        gVault.addStrategy(address(daiStrategy), 3333);
        gVault.addStrategy(address(usdcStrategy), 3333);
        gVault.addStrategy(address(usdtStrategy), 3333);
    }

    function genThreeCrv(
        uint256 amount,
        address _user
    ) public returns (uint256) {
        vm.startPrank(_user);
        DAI.approve(THREE_POOL, amount);
        USDC.approve(THREE_POOL, amount);
        if (ERC20(address(USDT)).allowance(_user, THREE_POOL) > 0) {
            ERC20(address(USDT)).safeApprove(THREE_POOL, 0);
        }
        ERC20(address(USDT)).safeApprove(THREE_POOL, amount);
        uint256 dai = amount;
        uint256 usdt = amount / 10 ** 12;
        uint256 usdc = amount / 10 ** 12;
        setStorage(
            _user,
            DAI.balanceOf.selector,
            address(DAI),
            type(uint256).max
        );
        setStorage(
            _user,
            USDC.balanceOf.selector,
            address(USDC),
            type(uint256).max
        );
        setStorage(
            _user,
            USDT.balanceOf.selector,
            address(USDT),
            type(uint256).max
        );

        ICurve3Pool(THREE_POOL).add_liquidity([dai, usdc, usdt], 0);

        vm.stopPrank();

        return THREE_POOL_TOKEN.balanceOf(_user);
    }

    function setStorage(
        address _user,
        bytes4 _selector,
        address _contract,
        uint256 value
    ) public {
        uint256 slot = stdstore
            .target(_contract)
            .sig(_selector)
            .with_key(_user)
            .find();
        vm.store(_contract, bytes32(slot), bytes32(value));
    }

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
}
