// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { YieldVault, Math } from "./YieldVault.sol";

contract YieldVaultMaxSetter is YieldVault {
    using Math for uint256;

    uint256 internal _maxWithdraw;
    uint256 internal _maxRedeem;

    constructor(address _asset) YieldVault(_asset, "YieldVaultMaxSetter", "yvMaxSet") {}

    function setMaxWithdraw(uint256 maxWithdraw_) public {
        _maxWithdraw = maxWithdraw_;
    }

    function setMaxRedeem(uint256 maxRedeem_) public {
        _maxRedeem = maxRedeem_;
    }

    function maxWithdraw(address owner) public view override virtual returns(uint256) {
        uint256 max = super.maxWithdraw(owner);
        return max > _maxWithdraw ? _maxWithdraw : max;
    }

    function maxRedeem(address owner) public view override virtual returns(uint256) {
        uint256 max = super.maxRedeem(owner);
        return max > _maxRedeem ? _maxRedeem : max;
    }

    function redeem(uint256 shares, address owner, address receiver) public override virtual returns(uint256) {
        require(shares <= maxRedeem(owner), "maxRedeem exceeded");
        return super.redeem(shares, owner, receiver); 
    }

    function withdraw(uint256 assets, address owner, address receiver) public override virtual returns(uint256) {
        require(assets <= maxWithdraw(owner), "maxWithdraw exceeded");
        return super.withdraw(assets, owner, receiver); 
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
        return (assets == 0 || supply == 0) ? assets : assets.mulDiv(supply, totalAssets(), rounding);
    }

    function _convertToAssets(
        uint256 shares,
        Math.Rounding rounding
    ) internal view virtual override returns (uint256) {
        uint256 supply = totalSupply();
        return (shares == 0 || supply == 0) ? shares : shares.mulDiv(totalAssets(), supply, rounding);
    }
    
}
