// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ERC4626Mock } from "openzeppelin/mocks/ERC4626Mock.sol";
import { Math } from "openzeppelin/utils/math/Math.sol";

contract YieldVault is ERC4626Mock {
    using Math for uint256;

    constructor(address _asset, string memory _name, string memory _symbol) ERC4626Mock(_asset) {}

    /**
     * We override the virtual shares and assets implementation since this approach captures
     * a very small part of the yield being accrued, which offsets by 1 wei
     * the withdrawable amount from the YieldVault and skews our unit tests equality comparisons.
     * Read this comment in the OpenZeppelin documentation to understand why:
     * https://github.com/openzeppelin/openzeppelin-contracts/blob/eedca5d873a559140d79cc7ec674d0e28b2b6ebd/contracts/token/ERC20/extensions/ERC4626.sol#L30
     */
    // function _convertToShares(
    //     uint256 assets,
    //     Math.Rounding rounding
    // ) internal view virtual override returns (uint256) {
    //     uint256 supply = totalSupply();
    //     return (assets == 0 || supply == 0) ? assets : assets.mulDiv(supply, totalAssets(), rounding);
    // }

    // function _convertToAssets(
    //     uint256 shares,
    //     Math.Rounding rounding
    // ) internal view virtual override returns (uint256) {
    //     uint256 supply = totalSupply();
    //     return (shares == 0 || supply == 0) ? shares : shares.mulDiv(totalAssets(), supply, rounding);
    // }
}
