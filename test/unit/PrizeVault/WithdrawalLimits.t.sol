// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IERC4626 } from "openzeppelin/token/ERC20/extensions/ERC4626.sol";
import { IERC20, UnitBaseSetup, PrizeVault } from "./UnitBaseSetup.t.sol";
import { YieldVaultMaxSetter } from "../../contracts/mock/YieldVaultMaxSetter.sol";

contract PrizeVaultWithdrawalLimitsTest is UnitBaseSetup {

    YieldVaultMaxSetter internal _yieldVaultMaxSetter;

    /* ============ override yield vault setup ============ */

    function setUpYieldVault() public virtual override returns (IERC4626) {
        _yieldVaultMaxSetter = new YieldVaultMaxSetter(address(underlyingAsset));
        return _yieldVaultMaxSetter;
    }

    /* ============ withdraw limit test ============ */
    
    // This is a regression test that demonstrates an issue when using maxWithdraw as the upper limit when redeeming
    // the shares that would be burned by the withdraw instead of calling the withdraw.
    //
    // - yield vault has 100 assets and a 1 share : 10 asset exchange rate
    // - max withdraw is 95 assets on the yield vault, max redeem is 9 shares (assets rounded down)
    // - alice wants to withdraw 95 assets from the prize vault
    // - prize vault attempts to redeem 10 shares so that the 5 share rounding error is not lost
    // - redemption fails since it exceeds the max redeem limit on the yield vault
    //
    // To pass this test, the prize vault MUST take into account the upper limit on the redemption when calculating
    // the maxWithdraw limit.

    function testWithdrawLimitNotPassedByRedeem() public {
        // offset the exchange rate by a factor of ten by depositing 9 assets in the yield vault after minting 1 share.
        vm.startPrank(bob);
        underlyingAsset.mint(bob, 10);
        underlyingAsset.approve(address(yieldVault), 10);
        yieldVault.deposit(1, bob);
        underlyingAsset.mint(address(yieldVault), 9);
        vm.stopPrank();

        assertEq(yieldVault.totalAssets(), 10);
        assertEq(yieldVault.totalSupply(), 1);

        // alice deposits 100 assets and the prize vault receives 10 shares
        vm.startPrank(alice);
        underlyingAsset.mint(alice, 100);
        underlyingAsset.approve(address(vault), 100);
        vault.deposit(100, alice);
        vm.stopPrank();

        assertEq(vault.balanceOf(alice), 100);
        assertEq(vault.totalAssets(), 100);
        assertEq(yieldVault.balanceOf(address(vault)), 10);

        // set max withdraw on yield vault to 95 assets and max redeem to 9 shares
        _yieldVaultMaxSetter.setMaxWithdraw(95);
        _yieldVaultMaxSetter.setMaxRedeem(9);

        assertEq(yieldVault.maxWithdraw(address(vault)), 95);
        assertEq(yieldVault.maxRedeem(address(vault)), 9);

        uint256 maxWithdrawAlice = vault.maxWithdraw(alice);

        assertEq(maxWithdrawAlice, 90);
        assertEq(vault.maxRedeem(alice), 90); // prize vault shares are 1:1 with assets

        // alice withdraws 90 assets
        vm.startPrank(alice);
        vault.withdraw(maxWithdrawAlice, alice, alice);
        vm.stopPrank();

        // set max withdraw on yield vault to 5 assets and max redeem to 0 shares after withdrawal
        _yieldVaultMaxSetter.setMaxWithdraw(5);
        _yieldVaultMaxSetter.setMaxRedeem(0);

        assertEq(vault.totalAssets(), 10);
        assertEq(vault.totalSupply(), 10);
        assertEq(yieldVault.balanceOf(address(vault)), 1);
        assertEq(vault.maxWithdraw(alice), 0); // no yv shares can be redeemed, so no pv assets can be withdrawn
        assertEq(vault.maxRedeem(alice), 0); // no yv shares can be redeemed, so no pv shares can be redeemed
    }

}