// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IERC4626 } from "openzeppelin/token/ERC20/extensions/ERC4626.sol";
import { IERC20, UnitBaseSetup, PrizeVault } from "./UnitBaseSetup.t.sol";

contract PrizeVaultDepositLossyProtection is UnitBaseSetup {

    /* ============ maxDeposit ============ */
        
    function testMaxDeposit_zeroWhenLossy() external {
        underlyingAsset.mint(alice, 1e18);

        assertGe(vault.maxDeposit(alice), 1e18);

        vm.startPrank(alice);
        underlyingAsset.approve(address(vault), 1e18);
        vault.deposit(1e18, alice);
        vm.stopPrank();

        underlyingAsset.mint(alice, 1e18);
        underlyingAsset.burn(address(yieldVault), 1); // lost 1 asset in yield vault, new deposits will be lossy

        assertEq(vault.maxDeposit(alice), 0);
    }

    /* ============ maxMint ============ */
        
    function testMaxMint_zeroWhenLossy() external {
        underlyingAsset.mint(alice, 1e18);

        assertGe(vault.maxMint(alice), 1e18);

        vm.startPrank(alice);
        underlyingAsset.approve(address(vault), 1e18);
        vault.mint(1e18, alice);
        vm.stopPrank();

        underlyingAsset.mint(alice, 1e18);
        underlyingAsset.burn(address(yieldVault), 1); // lost 1 asset in yield vault, new deposits will be lossy

        assertEq(vault.maxMint(alice), 0);
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

    /* ============ sponsor ============ */
        
    function testSponsor_revertWhenLossy() external {
        underlyingAsset.mint(alice, 1e18);

        vm.startPrank(alice);
        underlyingAsset.approve(address(vault), 1e18);
        vault.sponsor(1e18);
        vm.stopPrank();

        underlyingAsset.mint(alice, 1e18);
        underlyingAsset.burn(address(yieldVault), 1); // lost 1 asset in yield vault, new sponsors will be lossy

        vm.startPrank(alice);
        underlyingAsset.approve(address(vault), 1e18);
        vm.expectRevert(abi.encodeWithSelector(PrizeVault.LossyDeposit.selector, 2e18 - 1, 2e18));
        vault.sponsor(1e18);
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