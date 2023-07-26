// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import { MintMoreThanMax, DepositMoreThanMax } from "../../src/Vault.sol";

import { BrokenToken } from "brokentoken/BrokenToken.sol";

import { IERC20, UnitBaseSetup } from "../utils/UnitBaseSetup.t.sol";
import { console2 } from "forge-std/Test.sol";

contract VaultDepositTest is UnitBaseSetup, BrokenToken {
  /* ============ Events ============ */
  event Deposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares);

  event Sponsor(address indexed caller, address indexed receiver, uint256 assets, uint256 shares);

  event Transfer(address indexed from, address indexed to, uint256 value);

  event RecordedExchangeRate(uint256 exchangeRate);

  /* ============ Tests ============ */

  /* ============ Deposit ============ */
  function testDeposit() external {
    vm.startPrank(alice);

    uint256 _amount = 1000e18;
    underlyingAsset.mint(alice, _amount);
    underlyingAsset.approve(address(vault), type(uint256).max);

    vm.expectEmit();
    emit RecordedExchangeRate(1e18);

    vm.expectEmit();
    emit Transfer(address(0), alice, _amount);

    vm.expectEmit();
    emit Deposit(alice, alice, _amount, _amount);

    vault.deposit(_amount, alice);

    assertEq(vault.balanceOf(alice), _amount);

    assertEq(twabController.balanceOf(address(vault), alice), _amount);
    assertEq(twabController.delegateBalanceOf(address(vault), alice), _amount);

    assertEq(underlyingAsset.balanceOf(address(yieldVault)), _amount);
    assertEq(yieldVault.balanceOf(address(vault)), _amount);
    assertEq(yieldVault.totalSupply(), _amount);

    vm.stopPrank();
  }

  function testDepositMoreThanMax() external {
    vm.startPrank(alice);

    uint256 _moreThanMax = uint256(type(uint96).max) + 1;
    uint256 _amount = _moreThanMax;
    underlyingAsset.mint(alice, _amount);
    underlyingAsset.approve(address(vault), type(uint256).max);

    vm.expectRevert(abi.encodeWithSelector(DepositMoreThanMax.selector, alice, _amount, type(uint96).max));
    vault.deposit(_amount, alice);

    vm.stopPrank();
  }

  function testDepositAssetsLivingInVault() external {
    uint256 _vaultAmount = 500e18;
    underlyingAsset.mint(address(vault), _vaultAmount);

    assertEq(underlyingAsset.balanceOf(address(vault)), _vaultAmount);

    vm.startPrank(alice);

    uint256 _amount = 1000e18;
    underlyingAsset.mint(alice, _amount);
    underlyingAsset.approve(address(vault), type(uint256).max);

    vm.expectEmit();
    emit Transfer(address(0), alice, _amount);

    vm.expectEmit();
    emit Deposit(alice, alice, _amount, _amount);

    vault.deposit(_amount, alice);

    assertEq(vault.balanceOf(alice), _amount);

    assertEq(twabController.balanceOf(address(vault), alice), _amount);
    assertEq(twabController.delegateBalanceOf(address(vault), alice), _amount);

    assertEq(underlyingAsset.balanceOf(alice), _amount - _vaultAmount);
    assertEq(underlyingAsset.balanceOf(address(vault)), 0);
    assertEq(underlyingAsset.balanceOf(address(yieldVault)), _amount);

    assertEq(yieldVault.balanceOf(address(vault)), _amount);
    assertEq(yieldVault.totalSupply(), _amount);

    vm.stopPrank();
  }

  function testDepositOnBehalf() external {
    vm.startPrank(alice);

    uint256 _amount = 1000e18;
    underlyingAsset.mint(alice, _amount);
    underlyingAsset.approve(address(vault), type(uint256).max);

    vm.expectEmit();
    emit Transfer(address(0), bob, _amount);

    vm.expectEmit();
    emit Deposit(alice, bob, _amount, _amount);

    vault.deposit(_amount, bob);

    assertEq(vault.balanceOf(alice), 0);
    assertEq(vault.balanceOf(bob), _amount);

    assertEq(twabController.balanceOf(address(vault), alice), 0);
    assertEq(twabController.delegateBalanceOf(address(vault), alice), 0);

    assertEq(twabController.balanceOf(address(vault), bob), _amount);
    assertEq(twabController.delegateBalanceOf(address(vault), bob), _amount);

    assertEq(underlyingAsset.balanceOf(address(yieldVault)), _amount);
    assertEq(yieldVault.balanceOf(address(vault)), _amount);
    assertEq(yieldVault.totalSupply(), _amount);

    vm.stopPrank();
  }

  function testDepositWithPermit() external {
    vm.startPrank(alice);

    uint256 _amount = 1000e18;
    underlyingAsset.mint(alice, _amount);

    vm.expectEmit();
    emit Transfer(address(0), alice, _amount);

    vm.expectEmit();
    emit Deposit(alice, alice, _amount, _amount);

    _depositWithPermit(underlyingAsset, vault, _amount, alice, alice, alicePrivateKey);

    assertEq(vault.balanceOf(alice), _amount);

    assertEq(twabController.balanceOf(address(vault), alice), _amount);
    assertEq(twabController.delegateBalanceOf(address(vault), alice), _amount);

    assertEq(underlyingAsset.balanceOf(address(yieldVault)), _amount);
    assertEq(yieldVault.balanceOf(address(vault)), _amount);
    assertEq(yieldVault.totalSupply(), _amount);

    vm.stopPrank();
  }

  function testDepositWithPermitOnBehalf() external {
    vm.startPrank(alice);

    uint256 _amount = 1000e18;
    underlyingAsset.mint(alice, _amount);

    vm.expectEmit();
    emit Transfer(address(0), bob, _amount);

    vm.expectEmit();
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
    assertEq(yieldVault.totalSupply(), _amount);

    vm.stopPrank();
  }

  function testFailDepositInflationAttack() external {
    vm.startPrank(bob);

    uint256 _attackAmount = 1000e18;
    uint256 _bobAmount = 1;
    uint256 _bobTotalAmount = _attackAmount + _bobAmount;

    underlyingAsset.mint(bob, _attackAmount + _bobAmount);

    _deposit(underlyingAsset, vault, _bobAmount, bob);

    // Bob transfers 1,000 underlying assets into the Vault in the hope of manipulating the exchange rate
    underlyingAsset.transfer(address(vault), _attackAmount);

    assertEq(vault.totalSupply(), _bobAmount);
    assertEq(vault.totalAssets(), _bobTotalAmount);

    vm.stopPrank();

    vm.startPrank(alice);

    uint256 _amount = 10_000e18;
    underlyingAsset.mint(alice, _amount);
    underlyingAsset.approve(address(vault), type(uint256).max);

    vm.expectEmit();
    emit Transfer(address(0), alice, _amount);

    vm.expectEmit();
    emit Deposit(alice, alice, _amount, _amount);

    vault.deposit(_amount, alice);

    assertEq(vault.balanceOf(alice), _amount);

    /**
     * If assets are living in the Vault when a user deposits,
     * this amount of assets will offset the deposit amount
     * and we only transfer from the depositor the difference
     * (i.e. _amount - _attackAmount = 10,000 - 1,000 = 9,000)
     */
    assertEq(underlyingAsset.balanceOf(alice), _attackAmount);

    // The exchange rate has not been manipulated and is still equal to 1 unit of asset
    assertEq(vault.exchangeRate(), 10 ** 18);

    /**
     * Alice receives back the same amount of Vault shares than underlying assets deposited
     * despite the attempt by Bob to inflate the exchange rate.
     * This is because the exchange rate does not take into account
     * the amount of underlying assets living in the Vault.
     */
    assertEq(vault.balanceOf(alice), _amount);
    assertEq(IERC20(vault).balanceOf(alice), _amount);

    assertEq(twabController.balanceOf(address(vault), alice), _amount);
    assertEq(twabController.delegateBalanceOf(address(vault), alice), _amount);

    assertEq(underlyingAsset.balanceOf(address(yieldVault)), _amount + _bobAmount);
    assertEq(underlyingAsset.balanceOf(address(vault)), 0);

    assertEq(yieldVault.balanceOf(address(vault)), _amount + _bobAmount);
    assertEq(yieldVault.totalSupply(), _amount + _bobAmount);

    vm.stopPrank();

    vm.startPrank(bob);

    // Bob manipulation failed and he can only withdraw 1 wei of underlying assets
    assertEq(vault.maxWithdraw(bob), _bobAmount);
    assertEq(vault.balanceOf(bob), _bobAmount);

    /**
     * Bob tries to redeem 1.99 shares to benefit from the attack
     * but it reverts cause he can only withdraw 1 wei of shares.
     */
    vault.redeem(vault.exchangeRate() * 2 - 1, bob, bob);
    assertEq(underlyingAsset.balanceOf(bob), 0);

    vm.stopPrank();
  }

  /* ============ Mint ============ */
  function testMint() external {
    vm.startPrank(alice);

    uint256 _amount = 1000e18;
    underlyingAsset.mint(alice, _amount);
    underlyingAsset.approve(address(vault), type(uint256).max);

    vm.expectEmit();
    emit Transfer(address(0), alice, _amount);

    vm.expectEmit();
    emit Deposit(alice, alice, _amount, _amount);

    vault.mint(_amount, alice);

    assertEq(vault.balanceOf(alice), _amount);

    assertEq(twabController.balanceOf(address(vault), alice), _amount);
    assertEq(twabController.delegateBalanceOf(address(vault), alice), _amount);

    assertEq(underlyingAsset.balanceOf(address(yieldVault)), _amount);
    assertEq(yieldVault.balanceOf(address(vault)), _amount);
    assertEq(yieldVault.totalSupply(), _amount);

    vm.stopPrank();
  }

  function testMintOnBehalf() external {
    vm.startPrank(alice);

    uint256 _amount = 1000e18;
    underlyingAsset.mint(alice, _amount);
    underlyingAsset.approve(address(vault), type(uint256).max);

    vm.expectEmit();
    emit Transfer(address(0), bob, _amount);

    vm.expectEmit();
    emit Deposit(alice, bob, _amount, _amount);

    vault.mint(_amount, bob);

    assertEq(vault.balanceOf(alice), 0);
    assertEq(vault.balanceOf(bob), _amount);

    assertEq(twabController.balanceOf(address(vault), alice), 0);
    assertEq(twabController.delegateBalanceOf(address(vault), alice), 0);

    assertEq(twabController.balanceOf(address(vault), bob), _amount);
    assertEq(twabController.delegateBalanceOf(address(vault), bob), _amount);

    assertEq(underlyingAsset.balanceOf(address(yieldVault)), _amount);
    assertEq(yieldVault.balanceOf(address(vault)), _amount);
    assertEq(yieldVault.totalSupply(), _amount);

    vm.stopPrank();
  }

  function testMintWithPermit() external {
    vm.startPrank(alice);

    uint256 _amount = 1000e18;
    underlyingAsset.mint(alice, _amount);

    vm.expectEmit();
    emit Transfer(address(0), alice, _amount);

    vm.expectEmit();
    emit Deposit(alice, alice, _amount, _amount);

    _mintWithPermit(underlyingAsset, vault, _amount, alice, alice, alicePrivateKey);

    assertEq(vault.balanceOf(alice), _amount);

    assertEq(twabController.balanceOf(address(vault), alice), _amount);
    assertEq(twabController.delegateBalanceOf(address(vault), alice), _amount);

    assertEq(underlyingAsset.balanceOf(address(yieldVault)), _amount);
    assertEq(yieldVault.balanceOf(address(vault)), _amount);
    assertEq(yieldVault.totalSupply(), _amount);

    vm.stopPrank();
  }

  function testMintWithPermitOnBehalf() external {
    vm.startPrank(alice);

    uint256 _amount = 1000e18;
    underlyingAsset.mint(alice, _amount);

    vm.expectEmit();
    emit Transfer(address(0), bob, _amount);

    vm.expectEmit();
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
    assertEq(yieldVault.totalSupply(), _amount);

    vm.stopPrank();
  }

  function testMintMoreThanMax() external {
    vm.startPrank(alice);

    uint256 _amount = uint256(type(uint96).max) + 1;
    underlyingAsset.mint(alice, _amount);
    underlyingAsset.approve(address(vault), type(uint256).max);

    vm.expectRevert(abi.encodeWithSelector(MintMoreThanMax.selector, alice, _amount, type(uint96).max));

    vault.mint(_amount, alice);

    vm.stopPrank();
  }

  /* ============ Sponsor ============ */
  function testSponsor() external {
    vm.startPrank(alice);

    uint256 _amount = 1000e18;
    underlyingAsset.mint(alice, _amount);
    underlyingAsset.approve(address(vault), type(uint256).max);

    vm.expectEmit();
    emit Transfer(address(0), alice, _amount);

    vm.expectEmit();
    emit Sponsor(alice, alice, _amount, _amount);

    vault.sponsor(_amount, alice);

    assertEq(vault.balanceOf(alice), _amount);

    assertEq(twabController.balanceOf(address(vault), alice), _amount);
    assertEq(twabController.delegateBalanceOf(address(vault), alice), 0);

    assertEq(twabController.balanceOf(address(vault), SPONSORSHIP_ADDRESS), 0);
    assertEq(twabController.delegateBalanceOf(address(vault), SPONSORSHIP_ADDRESS), 0);

    assertEq(underlyingAsset.balanceOf(address(yieldVault)), _amount);
    assertEq(yieldVault.balanceOf(address(vault)), _amount);
    assertEq(yieldVault.totalSupply(), _amount);

    vm.stopPrank();
  }

  function testSponsorOnBehalf() external {
    vm.startPrank(alice);

    uint256 _amount = 1000e18;
    underlyingAsset.mint(alice, _amount);
    underlyingAsset.approve(address(vault), type(uint256).max);

    vm.expectEmit();
    emit Transfer(address(0), bob, _amount);

    vm.expectEmit();
    emit Sponsor(alice, bob, _amount, _amount);

    vault.sponsor(_amount, bob);

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
    assertEq(yieldVault.totalSupply(), _amount);

    vm.stopPrank();
  }

  function testSponsorWithPermit() external {
    vm.startPrank(alice);

    uint256 _amount = 1000e18;
    underlyingAsset.mint(alice, _amount);

    vm.expectEmit();
    emit Transfer(address(0), alice, _amount);

    vm.expectEmit();
    emit Sponsor(alice, alice, _amount, _amount);

    _sponsorWithPermit(underlyingAsset, vault, _amount, alice, alice, alicePrivateKey);

    assertEq(vault.balanceOf(alice), _amount);

    assertEq(twabController.balanceOf(address(vault), alice), _amount);
    assertEq(twabController.delegateBalanceOf(address(vault), alice), 0);

    assertEq(twabController.balanceOf(address(vault), SPONSORSHIP_ADDRESS), 0);
    assertEq(twabController.delegateBalanceOf(address(vault), SPONSORSHIP_ADDRESS), 0);

    assertEq(underlyingAsset.balanceOf(address(yieldVault)), _amount);
    assertEq(yieldVault.balanceOf(address(vault)), _amount);
    assertEq(yieldVault.totalSupply(), _amount);

    vm.stopPrank();
  }

  function testSponsorWithPermitOnBehalf() external {
    vm.startPrank(alice);

    uint256 _amount = 1000e18;
    underlyingAsset.mint(alice, _amount);

    vm.expectEmit();
    emit Transfer(address(0), bob, _amount);

    vm.expectEmit();
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
    assertEq(yieldVault.totalSupply(), _amount);

    vm.stopPrank();
  }

  function testSponsorAlreadyDelegateToSponsor() external {
    vm.startPrank(alice);

    uint256 _amount = 1000e18;
    underlyingAsset.mint(alice, _amount);
    underlyingAsset.approve(address(vault), type(uint256).max);

    twabController.delegate(address(vault), twabController.SPONSORSHIP_ADDRESS());
    
    vm.expectEmit();
    emit Transfer(address(0), alice, _amount);

    vm.expectEmit();
    emit Sponsor(alice, alice, _amount, _amount);

    vault.sponsor(_amount, alice);

    assertEq(vault.balanceOf(alice), _amount);

    assertEq(twabController.balanceOf(address(vault), alice), _amount);
    assertEq(twabController.delegateBalanceOf(address(vault), alice), 0);

    assertEq(twabController.balanceOf(address(vault), SPONSORSHIP_ADDRESS), 0);
    assertEq(twabController.delegateBalanceOf(address(vault), SPONSORSHIP_ADDRESS), 0);

    assertEq(underlyingAsset.balanceOf(address(yieldVault)), _amount);
    assertEq(yieldVault.balanceOf(address(vault)), _amount);
    assertEq(yieldVault.totalSupply(), _amount);

    vm.stopPrank();
  }

  /* ============ Delegate ============ */
  function testDelegate() external {
    vm.startPrank(alice);

    uint256 _amount = 1000e18;
    underlyingAsset.mint(alice, _amount);
    underlyingAsset.approve(address(vault), type(uint256).max);

    vm.expectEmit();
    emit Transfer(address(0), alice, _amount);

    vm.expectEmit();
    emit Deposit(alice, alice, _amount, _amount);

    vault.deposit(_amount, alice);

    twabController.delegate(address(vault), bob);

    assertEq(vault.balanceOf(alice), _amount);
    assertEq(vault.balanceOf(bob), 0);

    assertEq(twabController.balanceOf(address(vault), alice), _amount);
    assertEq(twabController.delegateBalanceOf(address(vault), alice), 0);

    assertEq(twabController.balanceOf(address(vault), bob), 0);
    assertEq(twabController.delegateBalanceOf(address(vault), bob), _amount);

    assertEq(underlyingAsset.balanceOf(address(yieldVault)), _amount);
    assertEq(yieldVault.balanceOf(address(vault)), _amount);
    assertEq(yieldVault.totalSupply(), _amount);

    vm.stopPrank();
  }
}
