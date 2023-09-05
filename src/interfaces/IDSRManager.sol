// SPDX-License-Identifier: AGPLv3
pragma solidity ^0.8.13;

interface IDSRManager {
    function join(address dst, uint256 wad) external;

    function daiBalance(address usr) external returns (uint256 wad);

    function exitAll(address dst) external;

    function exit(address dst, uint256 wad) external;

    function pieOf(address usr) external view returns (uint256 pie);

    function pot() external view returns (address);
}
