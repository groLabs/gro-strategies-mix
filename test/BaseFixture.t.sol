// SPDX-License-Identifier: AGPLv3
pragma solidity ^0.8.13;
import "forge-std/Test.sol";


contract BaseFixture is Test {
    function setUp() public virtual {
        assert(true);
    }
}
