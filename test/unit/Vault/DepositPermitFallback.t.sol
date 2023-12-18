// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import { IERC4626 } from "openzeppelin/token/ERC20/extensions/ERC4626.sol";

import { IERC20, UnitBaseSetup } from "../../utils/UnitBaseSetup.t.sol";
import "../../../src/Vault.sol";

import { ERC20PermitFallbackMock } from "../../contracts/mock/ERC20PermitFallbackMock.sol";
import { ERC20PermitMock } from "../../contracts/mock/ERC20PermitMock.sol";

contract VaultDepositTest is UnitBaseSetup {
  /* ============ Events ============ */
  event Deposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares);

  event Sponsor(address indexed caller, uint256 assets, uint256 shares);

  event Sweep(address indexed caller, uint256 assets);

  event Transfer(address indexed from, address indexed to, uint256 value);

  function setUpUnderlyingAsset() public override returns (ERC20PermitMock) {
    return ERC20PermitMock(address(new ERC20PermitFallbackMock()));
  }

  /* ============ Tests ============ */

  function testDepositWithoutPermit_AllowanceNotSet() external {
    vm.startPrank(alice);

    uint256 _amount = 1000e18;
    underlyingAsset.mint(alice, _amount);

    underlyingAsset.approve(address(vault), _amount * 2);

    vm.expectRevert(
      abi.encodeWithSelector(
        Vault.PermitAllowanceNotSet.selector,
        alice,
        address(vault),
        _amount,
        _amount * 2
      )
    );

    uint8 _v = 0;
    bytes32 _r = bytes32(0);
    bytes32 _s = bytes32(0);
    vault.depositWithPermit(_amount, alice, block.timestamp, _v, _r, _s);

    vm.stopPrank();
  }

  function testForceDepositWithoutPermitByThirdParty() external {
    vm.startPrank(alice);

    uint256 _amount = 1000e18;
    underlyingAsset.mint(alice, _amount);

    underlyingAsset.approve(address(vault), _amount);

    vm.stopPrank();

    vm.expectRevert(
      abi.encodeWithSelector(Vault.PermitCallerNotOwner.selector, address(this), alice)
    );

    uint8 _v = 0;
    bytes32 _r = bytes32(0);
    bytes32 _s = bytes32(0);
    vault.depositWithPermit(_amount, alice, block.timestamp, _v, _r, _s);
  }

  function testFailPermitSign() external {
    vm.startPrank(alice);

    uint256 _amount = 1000e18;
    underlyingAsset.mint(alice, _amount);

    (uint8 _v, bytes32 _r, bytes32 _s) = _signPermit(
      underlyingAsset,
      vault,
      _amount,
      alice,
      alicePrivateKey
    );

    vm.stopPrank();
  }
}
