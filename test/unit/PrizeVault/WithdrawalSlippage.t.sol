// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IERC4626 } from "openzeppelin/token/ERC20/extensions/ERC4626.sol";
import { IERC20, UnitBaseSetup, PrizeVault } from "./UnitBaseSetup.t.sol";
import { YieldVaultMaxSetter } from "../../contracts/mock/YieldVaultMaxSetter.sol";

contract PrizeVaultWithdrawalSlippageTest is UnitBaseSetup {

    /* ============ withdraw slippage test ============ */

    function testWithdrawSlippage() public {
        // alice deposits 100 assets and receives 100 shares
        vm.startPrank(alice);
        underlyingAsset.mint(alice, 100);
        underlyingAsset.approve(address(vault), 100);
        vault.deposit(100, alice);
        vm.stopPrank();

        assertEq(vault.balanceOf(alice), 100);
        assertEq(vault.totalPreciseAssets(), 100);

        // yield vault loses 50% of assets
        vm.startPrank(address(yieldVault));
        underlyingAsset.burn(address(yieldVault), 50);
        vm.stopPrank();

        assertEq(vault.totalPreciseAssets(), 50);

        // alice should be able to withdraw up to 50 assets for 100 shares
        assertEq(vault.maxWithdraw(alice), 50);
        assertEq(vault.maxRedeem(alice), 100);
        assertEq(vault.previewWithdraw(50), 100);

        vm.startPrank(alice);
        {
            // make a snapshot
            uint256 snap = vm.snapshot();

            // should fail if 99 shares is passed as the limit
            vm.expectRevert(abi.encodeWithSelector(PrizeVault.MaxSharesExceeded.selector, 100, 99));
            vault.withdraw(50, alice, alice, 99);

            // should succeed if 100 shares is passed as the limit
            vm.revertTo(snap);
            uint256 shares = vault.withdraw(50, alice, alice, 100);
            assertEq(shares, 100);

            // should succeed if 101 shares is passed as the limit
            vm.revertTo(snap);
            shares = vault.withdraw(50, alice, alice, 101);
            assertEq(shares, 100); // still only uses 100
        }
        vm.stopPrank();
    }

    /* ============ redeem slippage test ============ */

    function testRedeemSlippage() public {
        // alice deposits 100 assets and receives 100 shares
        vm.startPrank(alice);
        underlyingAsset.mint(alice, 100);
        underlyingAsset.approve(address(vault), 100);
        vault.deposit(100, alice);
        vm.stopPrank();

        assertEq(vault.balanceOf(alice), 100);
        assertEq(vault.totalPreciseAssets(), 100);

        // yield vault loses 50% of assets
        vm.startPrank(address(yieldVault));
        underlyingAsset.burn(address(yieldVault), 50);
        vm.stopPrank();

        assertEq(vault.totalPreciseAssets(), 50);

        // alice should be able to redeem up to 100 shares for 50 assets
        assertEq(vault.maxWithdraw(alice), 50);
        assertEq(vault.maxRedeem(alice), 100);
        assertEq(vault.previewRedeem(100), 50);

        vm.startPrank(alice);
        {
            // make a snapshot
            uint256 snap = vm.snapshot();

            // should fail if 51 assets is passed as the threshold
            vm.expectRevert(abi.encodeWithSelector(PrizeVault.MinAssetsNotReached.selector, 50, 51));
            vault.redeem(100, alice, alice, 51);

            // should succeed if 50 assets is passed as the threshold
            vm.revertTo(snap);
            uint256 assets = vault.redeem(100, alice, alice, 50);
            assertEq(assets, 50);

            // should succeed if 49 assets is passed as the threshold
            vm.revertTo(snap);
            assets = vault.redeem(100, alice, alice, 49);
            assertEq(assets, 50); // still returns 50 assets
        }
        vm.stopPrank();
    }

}