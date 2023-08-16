// SPDX-License-Identifier: AGPLv3
pragma solidity ^0.8.13;
import "forge-std/Test.sol";
import "../src/external/GVault.sol";
import {FluxStrategy} from "../src/FluxStrategy.sol";

contract BaseFixture is Test {
    ERC20 public constant THREE_POOL_TOKEN =
        ERC20(address(0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490));

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

    function setUp() public virtual {
        gVault = new GVault(THREE_POOL_TOKEN);
        daiStrategy = new FluxStrategy(address(gVault), DAI, F_DAI);
        usdcStrategy = new FluxStrategy(address(gVault), USDC, F_USDC);
        usdtStrategy = new FluxStrategy(address(gVault), USDT, F_USDT);
    }
}
