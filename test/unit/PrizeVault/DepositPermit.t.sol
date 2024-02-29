// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IERC4626 } from "openzeppelin/token/ERC20/extensions/ERC4626.sol";
import { IERC20, UnitBaseSetup, PrizeVault } from "./UnitBaseSetup.t.sol";

contract PrizeVaultDepositPermitTest is UnitBaseSetup {

    /* ============ depositWithPermit ============ */
        
    function testDepositWithPermit() external {
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

        vm.expectEmit();
        emit Transfer(address(0), alice, _amount);

        vm.expectEmit();
        emit Deposit(alice, alice, _amount, _amount);

        vault.depositWithPermit(_amount, alice, block.timestamp, _v, _r, _s);

        assertEq(vault.balanceOf(alice), _amount);

        assertEq(twabController.balanceOf(address(vault), alice), _amount);
        assertEq(twabController.delegateBalanceOf(address(vault), alice), _amount);

        assertEq(underlyingAsset.balanceOf(address(yieldVault)), _amount);
        assertEq(yieldVault.balanceOf(address(vault)), _amount);
        assertEq(yieldVault.totalSupply(), _amount);

        vm.stopPrank();
    }

    function testDepositWithPermitByThirdParty_CallerNotOwner() external {
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
        vm.expectRevert(
            abi.encodeWithSelector(PrizeVault.PermitCallerNotOwner.selector, address(this), alice)
        );
        vault.depositWithPermit(_amount, alice, block.timestamp, _v, _r, _s);
    }

    function testDepositWithPermit_Frontrun() external {
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

        // should normally go through:
        uint256 beforeDeposit = vm.snapshot();
        vault.depositWithPermit(_amount, alice, block.timestamp, _v, _r, _s);
        assertEq(vault.balanceOf(alice), _amount);
        vm.revertTo(beforeDeposit);

        vm.stopPrank();

        // Alice gets frontrun by a griefer that wants to prevent her transaction from going through.
        // They call `permit` with her signature on the underlying asset to try and cause her tx to fail.
        underlyingAsset.permit(alice, address(vault), _amount, block.timestamp, _v, _r, _s);
        assertEq(underlyingAsset.allowance(alice, address(vault)), _amount);

        // Since the allowance is the same as alice's deposit call, it goes through anyway and alice spends
        // a bit less gas thanks to the frontrunner.
        vm.startPrank(alice);
        vault.depositWithPermit(_amount, alice, block.timestamp, _v, _r, _s);
        assertEq(vault.balanceOf(alice), _amount);
        vm.stopPrank();
    }

}