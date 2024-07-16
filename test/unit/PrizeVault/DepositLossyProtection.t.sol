// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IERC4626 } from "openzeppelin/token/ERC20/extensions/ERC4626.sol";
import { IERC20, UnitBaseSetup, PrizeVault } from "./UnitBaseSetup.t.sol";

contract PrizeVaultDepositLossyProtection is UnitBaseSetup {

    /* ============ maxDeposit ============ */
        
    function testMaxDeposit_zeroWhenYieldBufferLessThanHalfFull() external {
        underlyingAsset.mint(alice, 1e18);
        
        uint256 _yieldBuffer = vault.yieldBuffer();
        assertGt(_yieldBuffer, 0);
        underlyingAsset.mint(address(vault), _yieldBuffer / 2);

        assertGe(vault.maxDeposit(alice), 1e18); // maxDeposit returns some normal value

        vm.startPrank(alice);
        underlyingAsset.approve(address(vault), 1e18);
        vault.deposit(1e18, alice);
        vm.stopPrank();

        assertEq(vault.currentYieldBuffer(), _yieldBuffer / 2); // check that yield buffer is still the same
        underlyingAsset.burn(address(yieldVault), 1); // lost 1 asset in yield vault
        assertEq(vault.currentYieldBuffer(), _yieldBuffer / 2 - 1); // yield buffer no longer is now less than half

        assertEq(vault.maxDeposit(alice), 0); // maxDeposit is now zero
    }

    /* ============ maxMint ============ */

    function testMaxMint_zeroWhenYieldBufferLessThanHalfFull() external {
        underlyingAsset.mint(alice, 1e18);
        
        uint256 _yieldBuffer = vault.yieldBuffer();
        assertGt(_yieldBuffer, 0);
        underlyingAsset.mint(address(vault), _yieldBuffer / 2);

        assertGe(vault.maxMint(alice), 1e18); // maxMint returns some normal value

        vm.startPrank(alice);
        underlyingAsset.approve(address(vault), 1e18);
        vault.mint(1e18, alice);
        vm.stopPrank();

        assertEq(vault.currentYieldBuffer(), _yieldBuffer / 2); // check that yield buffer is still the same
        underlyingAsset.burn(address(yieldVault), 1); // lost 1 asset in yield vault
        assertEq(vault.currentYieldBuffer(), _yieldBuffer / 2 - 1); // yield buffer no longer is now less than half

        assertEq(vault.maxMint(alice), 0); // maxMint is now zero
    }

    /* ============ convertToShares ============ */
        
    function testConvertToShares_ProportionalWhenLossy() external {
        underlyingAsset.mint(alice, 1e18);

        assertEq(vault.convertToShares(1e18), 1e18);

        vm.startPrank(alice);
        underlyingAsset.approve(address(vault), 1e18);
        vault.mint(1e18, alice);
        vm.stopPrank();

        underlyingAsset.mint(alice, 1e18);
        underlyingAsset.burn(address(yieldVault), 1e18 / 2); // lost 50% of assets in yield vault

        assertEq(vault.convertToShares(1e18), 1e18 * 2); // 1 asset is now worth 2 shares
    }

    /* ============ convertToAssets ============ */
        
    function testConvertToAssets_ProportionalWhenLossy() external {
        underlyingAsset.mint(alice, 1e18);

        assertEq(vault.convertToAssets(1e18), 1e18);

        vm.startPrank(alice);
        underlyingAsset.approve(address(vault), 1e18);
        vault.mint(1e18, alice);
        vm.stopPrank();

        underlyingAsset.mint(alice, 1e18);
        underlyingAsset.burn(address(yieldVault), 1e18 / 2); // lost 50% of assets in yield vault

        assertEq(vault.convertToAssets(1e18), 1e18 / 2); // 1 share is now worth 0.5 assets
    }

    /* ============ deposit ============ */
        
    function testDeposit_revertWhenLossy() external {
        underlyingAsset.mint(alice, 1e18);

        vm.startPrank(alice);
        underlyingAsset.approve(address(vault), 1e18);
        vault.deposit(1e18, alice);
        vm.stopPrank();

        underlyingAsset.mint(alice, 1e18);
        underlyingAsset.burn(address(yieldVault), 1); // lost 1 asset in yield vault, new deposits will be lossy

        vm.startPrank(alice);
        underlyingAsset.approve(address(vault), 1e18);
        vm.expectRevert(abi.encodeWithSelector(PrizeVault.LossyDeposit.selector, 2e18 - 1, 2e18));
        vault.deposit(1e18, alice);
        vm.stopPrank();
    }

    /* ============ mint ============ */
        
    function testMint_revertWhenLossy() external {
        underlyingAsset.mint(alice, 1e18);

        vm.startPrank(alice);
        underlyingAsset.approve(address(vault), 1e18);
        vault.mint(1e18, alice);
        vm.stopPrank();

        underlyingAsset.mint(alice, 1e18);
        underlyingAsset.burn(address(yieldVault), 1); // lost 1 asset in yield vault, new mints will be lossy

        vm.startPrank(alice);
        underlyingAsset.approve(address(vault), 1e18);
        vm.expectRevert(abi.encodeWithSelector(PrizeVault.LossyDeposit.selector, 2e18 - 1, 2e18));
        vault.mint(1e18, alice);
        vm.stopPrank();
    }

    /* ============ depositWithPermit ============ */
        
    function testDepositWithPermit_revertWhenLossy() external {
        underlyingAsset.mint(alice, 1e18);

        (uint8 _v, bytes32 _r, bytes32 _s) = _signPermit(
            underlyingAsset,
            vault,
            1e18,
            alice,
            alicePrivateKey
        );

        vm.startPrank(alice);
        vault.depositWithPermit(1e18, alice, block.timestamp, _v, _r, _s);
        vm.stopPrank();

        underlyingAsset.mint(alice, 1e18);
        underlyingAsset.burn(address(yieldVault), 1); // lost 1 asset in yield vault, new deposits will be lossy

        (_v, _r, _s) = _signPermit(
            underlyingAsset,
            vault,
            1e18,
            alice,
            alicePrivateKey
        );

        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(PrizeVault.LossyDeposit.selector, 2e18 - 1, 2e18));
        vault.depositWithPermit(1e18, alice, block.timestamp, _v, _r, _s);
        vm.stopPrank();
    }

}