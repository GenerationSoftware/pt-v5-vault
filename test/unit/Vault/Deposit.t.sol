// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import { Helpers } from "test/utils/Helpers.t.sol";
import { UnitBaseSetup } from "test/utils/UnitBaseSetup.t.sol";

contract VaultDepositTest is UnitBaseSetup, Helpers {
  /* ============ Events ============ */
  event Deposit(address indexed caller, address indexed receiver, uint256 assets, uint256 shares);

  event Sponsor(address indexed caller, address indexed receiver, uint256 assets, uint256 shares);

  /* ============ Tests ============ */

  /* ============ Deposit ============ */
  function testDeposit() external {
    vm.startPrank(alice);

    uint256 _amount = 1000e18;
    underlyingAsset.mint(alice, _amount);

    vm.expectEmit(true, true, true, true);
    emit Deposit(alice, alice, _amount, _amount);

    _deposit(underlyingAsset, vault, _amount, alice);

    assertEq(vault.balanceOf(alice), _amount);

    assertEq(twabController.balanceOf(address(vault), alice), _amount);
    assertEq(twabController.delegateBalanceOf(address(vault), alice), _amount);

    assertEq(underlyingAsset.balanceOf(address(yieldVault)), _amount);
    assertEq(yieldVault.balanceOf(address(vault)), _amount);

    vm.stopPrank();
  }

  function testDepositOnBehalf() external {
    vm.startPrank(alice);

    uint256 _amount = 1000e18;
    underlyingAsset.mint(alice, _amount);

    vm.expectEmit(true, true, true, true);
    emit Deposit(alice, bob, _amount, _amount);

    _deposit(underlyingAsset, vault, _amount, bob);

    assertEq(vault.balanceOf(alice), 0);
    assertEq(vault.balanceOf(bob), _amount);

    assertEq(twabController.balanceOf(address(vault), alice), 0);
    assertEq(twabController.delegateBalanceOf(address(vault), alice), 0);

    assertEq(twabController.balanceOf(address(vault), bob), _amount);
    assertEq(twabController.delegateBalanceOf(address(vault), bob), _amount);

    assertEq(underlyingAsset.balanceOf(address(yieldVault)), _amount);
    assertEq(yieldVault.balanceOf(address(vault)), _amount);

    vm.stopPrank();
  }

  function testDepositWithPermit() external {
    vm.startPrank(alice);

    uint256 _amount = 1000e18;
    underlyingAsset.mint(alice, _amount);

    vm.expectEmit(true, true, true, true);
    emit Deposit(alice, alice, _amount, _amount);

    _depositWithPermit(underlyingAsset, vault, _amount, alice, alice, alicePrivateKey);

    assertEq(vault.balanceOf(alice), _amount);

    assertEq(twabController.balanceOf(address(vault), alice), _amount);
    assertEq(twabController.delegateBalanceOf(address(vault), alice), _amount);

    assertEq(underlyingAsset.balanceOf(address(yieldVault)), _amount);
    assertEq(yieldVault.balanceOf(address(vault)), _amount);

    vm.stopPrank();
  }

  function testDepositWithPermitOnBehalf() external {
    vm.startPrank(alice);

    uint256 _amount = 1000e18;
    underlyingAsset.mint(alice, _amount);

    vm.expectEmit(true, true, true, true);
    emit Deposit(alice, bob, _amount, _amount);

    _depositWithPermit(underlyingAsset, vault, _amount, bob, alice, alicePrivateKey);

    assertEq(vault.balanceOf(alice), 0);
    assertEq(vault.balanceOf(bob), _amount);

    assertEq(twabController.balanceOf(address(vault), alice), 0);
    assertEq(twabController.delegateBalanceOf(address(vault), alice), 0);

    assertEq(twabController.balanceOf(address(vault), bob), _amount);
    assertEq(twabController.delegateBalanceOf(address(vault), bob), _amount);

    assertEq(underlyingAsset.balanceOf(address(yieldVault)), _amount);
    assertEq(yieldVault.balanceOf(address(vault)), _amount);

    vm.stopPrank();
  }

  /* ============ Mint ============ */
  function testMint() external {
    vm.startPrank(alice);

    uint256 _amount = 1000e18;
    underlyingAsset.mint(alice, _amount);

    vm.expectEmit(true, true, true, true);
    emit Deposit(alice, alice, _amount, _amount);

    _mint(underlyingAsset, vault, _amount, alice);

    assertEq(vault.balanceOf(alice), _amount);

    assertEq(twabController.balanceOf(address(vault), alice), _amount);
    assertEq(twabController.delegateBalanceOf(address(vault), alice), _amount);

    assertEq(underlyingAsset.balanceOf(address(yieldVault)), _amount);
    assertEq(yieldVault.balanceOf(address(vault)), _amount);

    vm.stopPrank();
  }

  function testMintOnBehalf() external {
    vm.startPrank(alice);

    uint256 _amount = 1000e18;
    underlyingAsset.mint(alice, _amount);

    vm.expectEmit(true, true, true, true);
    emit Deposit(alice, bob, _amount, _amount);

    _mint(underlyingAsset, vault, _amount, bob);

    assertEq(vault.balanceOf(alice), 0);
    assertEq(vault.balanceOf(bob), _amount);

    assertEq(twabController.balanceOf(address(vault), alice), 0);
    assertEq(twabController.delegateBalanceOf(address(vault), alice), 0);

    assertEq(twabController.balanceOf(address(vault), bob), _amount);
    assertEq(twabController.delegateBalanceOf(address(vault), bob), _amount);

    assertEq(underlyingAsset.balanceOf(address(yieldVault)), _amount);
    assertEq(yieldVault.balanceOf(address(vault)), _amount);

    vm.stopPrank();
  }

  function testMintWithPermit() external {
    vm.startPrank(alice);

    uint256 _amount = 1000e18;
    underlyingAsset.mint(alice, _amount);

    vm.expectEmit(true, true, true, true);
    emit Deposit(alice, alice, _amount, _amount);

    _mintWithPermit(underlyingAsset, vault, _amount, alice, alice, alicePrivateKey);

    assertEq(vault.balanceOf(alice), _amount);

    assertEq(twabController.balanceOf(address(vault), alice), _amount);
    assertEq(twabController.delegateBalanceOf(address(vault), alice), _amount);

    assertEq(underlyingAsset.balanceOf(address(yieldVault)), _amount);
    assertEq(yieldVault.balanceOf(address(vault)), _amount);

    vm.stopPrank();
  }

  function testMintWithPermitOnBehalf() external {
    vm.startPrank(alice);

    uint256 _amount = 1000e18;
    underlyingAsset.mint(alice, _amount);

    vm.expectEmit(true, true, true, true);
    emit Deposit(alice, bob, _amount, _amount);

    _mintWithPermit(underlyingAsset, vault, _amount, bob, alice, alicePrivateKey);

    assertEq(vault.balanceOf(alice), 0);
    assertEq(vault.balanceOf(bob), _amount);

    assertEq(twabController.balanceOf(address(vault), alice), 0);
    assertEq(twabController.delegateBalanceOf(address(vault), alice), 0);

    assertEq(twabController.balanceOf(address(vault), bob), _amount);
    assertEq(twabController.delegateBalanceOf(address(vault), bob), _amount);

    assertEq(underlyingAsset.balanceOf(address(yieldVault)), _amount);
    assertEq(yieldVault.balanceOf(address(vault)), _amount);

    vm.stopPrank();
  }

  /* ============ Sponsor ============ */
  function testSponsor() external {
    vm.startPrank(alice);

    uint256 _amount = 1000e18;
    underlyingAsset.mint(alice, _amount);

    vm.expectEmit(true, true, true, true);
    emit Sponsor(alice, alice, _amount, _amount);

    _sponsor(underlyingAsset, vault, _amount, alice);

    assertEq(vault.balanceOf(alice), _amount);

    assertEq(twabController.balanceOf(address(vault), alice), _amount);
    assertEq(twabController.delegateBalanceOf(address(vault), alice), 0);

    assertEq(twabController.balanceOf(address(vault), SPONSORSHIP_ADDRESS), 0);
    assertEq(twabController.delegateBalanceOf(address(vault), SPONSORSHIP_ADDRESS), 0);

    assertEq(underlyingAsset.balanceOf(address(yieldVault)), _amount);
    assertEq(yieldVault.balanceOf(address(vault)), _amount);

    vm.stopPrank();
  }

  function testSponsorOnBehalf() external {
    vm.startPrank(alice);

    uint256 _amount = 1000e18;
    underlyingAsset.mint(alice, _amount);

    vm.expectEmit(true, true, true, true);
    emit Sponsor(alice, bob, _amount, _amount);

    _sponsor(underlyingAsset, vault, _amount, bob);

    assertEq(vault.balanceOf(alice), 0);
    assertEq(vault.balanceOf(bob), _amount);

    assertEq(twabController.balanceOf(address(vault), alice), 0);
    assertEq(twabController.delegateBalanceOf(address(vault), alice), 0);

    assertEq(twabController.balanceOf(address(vault), bob), _amount);
    assertEq(twabController.delegateBalanceOf(address(vault), bob), 0);

    assertEq(twabController.balanceOf(address(vault), SPONSORSHIP_ADDRESS), 0);
    assertEq(twabController.delegateBalanceOf(address(vault), SPONSORSHIP_ADDRESS), 0);

    assertEq(underlyingAsset.balanceOf(address(yieldVault)), _amount);
    assertEq(yieldVault.balanceOf(address(vault)), _amount);

    vm.stopPrank();
  }

  function testSponsorWithPermit() external {
    vm.startPrank(alice);

    uint256 _amount = 1000e18;
    underlyingAsset.mint(alice, _amount);

    vm.expectEmit(true, true, true, true);
    emit Sponsor(alice, alice, _amount, _amount);

    _sponsorWithPermit(underlyingAsset, vault, _amount, alice, alice, alicePrivateKey);

    assertEq(vault.balanceOf(alice), _amount);

    assertEq(twabController.balanceOf(address(vault), alice), _amount);
    assertEq(twabController.delegateBalanceOf(address(vault), alice), 0);

    assertEq(twabController.balanceOf(address(vault), SPONSORSHIP_ADDRESS), 0);
    assertEq(twabController.delegateBalanceOf(address(vault), SPONSORSHIP_ADDRESS), 0);

    assertEq(underlyingAsset.balanceOf(address(yieldVault)), _amount);
    assertEq(yieldVault.balanceOf(address(vault)), _amount);

    vm.stopPrank();
  }

  function testSponsorWithPermitOnBehalf() external {
    vm.startPrank(alice);

    uint256 _amount = 1000e18;
    underlyingAsset.mint(alice, _amount);

    vm.expectEmit(true, true, true, true);
    emit Sponsor(alice, bob, _amount, _amount);

    _sponsorWithPermit(underlyingAsset, vault, _amount, bob, alice, alicePrivateKey);

    assertEq(vault.balanceOf(alice), 0);
    assertEq(vault.balanceOf(bob), _amount);

    assertEq(twabController.balanceOf(address(vault), alice), 0);
    assertEq(twabController.delegateBalanceOf(address(vault), alice), 0);

    assertEq(twabController.balanceOf(address(vault), bob), _amount);
    assertEq(twabController.delegateBalanceOf(address(vault), bob), 0);

    assertEq(twabController.balanceOf(address(vault), SPONSORSHIP_ADDRESS), 0);
    assertEq(twabController.delegateBalanceOf(address(vault), SPONSORSHIP_ADDRESS), 0);

    assertEq(underlyingAsset.balanceOf(address(yieldVault)), _amount);
    assertEq(yieldVault.balanceOf(address(vault)), _amount);

    vm.stopPrank();
  }

  /* ============ Delegate ============ */
  function testDelegate() external {
    vm.startPrank(alice);

    uint256 _amount = 1000e18;
    underlyingAsset.mint(alice, _amount);

    _deposit(underlyingAsset, vault, _amount, alice);

    twabController.delegate(address(vault), bob);

    assertEq(vault.balanceOf(alice), _amount);
    assertEq(vault.balanceOf(bob), 0);

    assertEq(twabController.balanceOf(address(vault), alice), _amount);
    assertEq(twabController.delegateBalanceOf(address(vault), alice), 0);

    assertEq(twabController.balanceOf(address(vault), bob), 0);
    assertEq(twabController.delegateBalanceOf(address(vault), bob), _amount);

    assertEq(underlyingAsset.balanceOf(address(yieldVault)), _amount);
    assertEq(yieldVault.balanceOf(address(vault)), _amount);

    vm.stopPrank();
  }
}
