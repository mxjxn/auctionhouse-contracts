// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

/// @author: manifold.xyz

import "@openzeppelin/utils/introspection/IERC165.sol";

interface IPriceEngine is IERC165 {

    /**
     *  @dev Determine price of an asset given the number
     *  already minted.
     */
    function price(uint256 assetId, uint256 alreadyMinted, uint24 count) view external returns (uint256);

}
