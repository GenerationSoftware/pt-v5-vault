// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import { ERC20Mock } from "openzeppelin/mocks/ERC20Mock.sol";
import { ERC4626Mock, IERC20, IERC20Metadata } from "openzeppelin/mocks/ERC4626Mock.sol";
import { Math } from "openzeppelin/utils/math/Math.sol";

contract YieldVault is ERC4626Mock {
  using Math for uint256;

  constructor(address _asset, string memory _name, string memory _symbol) ERC4626Mock(_asset) {}

  function burnAssets(address _account, uint256 _assets) external {
    ERC20Mock(asset()).burn(_account, _assets);
  }

  /**
   * We override the virtual shares and assets implementation since this approach captures
   * a very small part of the yield being accrued, which offsets by 1 wei
   * the withdrawable amount from the YieldVault and skews our unit tests equality comparisons.
   * Read this comment in the OpenZeppelin documentation to understand why:
   * https://github.com/openzeppelin/openzeppelin-contracts/blob/eedca5d873a559140d79cc7ec674d0e28b2b6ebd/contracts/token/ERC20/extensions/ERC4626.sol#L30
   */
  function _convertToShares(
    uint256 assets,
    Math.Rounding rounding
  ) internal view virtual override returns (uint256) {
    uint256 supply = totalSupply();
    return
      (assets == 0 || supply == 0)
        ? _initialConvertToShares(assets, rounding)
        : assets.mulDiv(supply, totalAssets(), rounding);
  }

  function _initialConvertToShares(
    uint256 assets,
    Math.Rounding /*rounding*/
  ) internal view virtual returns (uint256 shares) {
    return assets;
  }

  function _initialConvertToAssets(
    uint256 shares,
    Math.Rounding /*rounding*/
  ) internal view virtual returns (uint256) {
    return shares;
  }

  function _convertToAssets(
    uint256 shares,
    Math.Rounding rounding
  ) internal view virtual override returns (uint256) {
    uint256 supply = totalSupply();
    return
      (supply == 0)
        ? _initialConvertToAssets(shares, rounding)
        : shares.mulDiv(totalAssets(), supply, rounding);
  }
}
