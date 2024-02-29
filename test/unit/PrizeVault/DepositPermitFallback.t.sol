// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IERC4626 } from "openzeppelin/token/ERC20/extensions/ERC4626.sol";

import { IERC20, UnitBaseSetup, PrizeVault } from "./UnitBaseSetup.t.sol";

import { ERC20PermitFallbackMock } from "../../contracts/mock/ERC20PermitFallbackMock.sol";
import { ERC20PermitMock } from "../../contracts/mock/ERC20PermitMock.sol";

contract PrizeVaultDepositPermitFallbackTest is UnitBaseSetup {

    /* ============ setup ============ */

    function setUpUnderlyingAsset() public override returns (ERC20PermitMock) {
        return ERC20PermitMock(address(new ERC20PermitFallbackMock()));
    }

    /* ============ tests ============ */

    function testDepositWithoutPermit_SucceedsIfApprovalIsExact() external {
        vm.startPrank(alice);

        uint256 _amount = 1000e18;
        underlyingAsset.mint(alice, _amount);

        underlyingAsset.approve(address(vault), _amount); // exact approval

        uint8 _v = 0;
        bytes32 _r = bytes32(0);
        bytes32 _s = bytes32(0);
        vault.depositWithPermit(_amount, alice, block.timestamp, _v, _r, _s);

        assertEq(vault.balanceOf(alice), _amount);

        vm.stopPrank();
    }

    function testForceDepositWithoutPermitByThirdParty() external {
        vm.startPrank(alice);

        uint256 _amount = 1000e18;
        underlyingAsset.mint(alice, _amount);

        underlyingAsset.approve(address(vault), _amount);

        vm.stopPrank();

        vm.expectRevert(
            abi.encodeWithSelector(PrizeVault.PermitCallerNotOwner.selector, address(this), alice)
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
