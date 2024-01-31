// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ERC20Mock } from "openzeppelin/mocks/ERC20Mock.sol";
import { IERC4626 } from "openzeppelin/token/ERC20/extensions/ERC4626.sol";
import { IERC20, UnitBaseSetup, PrizeVault } from "./UnitBaseSetup.t.sol";

contract PrizeVaultLiquidationTest is UnitBaseSetup {

    /* ============ liquidatableBalanceOf ============ */

    function testLiquidatableBalanceOf_wrongToken() public {
        ERC20Mock otherToken = new ERC20Mock();
        assertNotEq(address(otherToken), address(vault.asset()));

        otherToken.mint(address(vault), 1e18);
        assertEq(vault.liquidatableBalanceOf(address(otherToken)), 0);
    }

    function testLiquidatableBalanceOf_noFee() public {
        vault.setYieldFeePercentage(0); // no fee

        underlyingAsset.mint(address(vault), 1e18);
        assertEq(vault.liquidatableBalanceOf(address(underlyingAsset)), 1e18 - vault.yieldBuffer());
    }

    function testLiquidatableBalanceOf_withFee() public {
        vault.setYieldFeePercentage(1e8); // 10%

        underlyingAsset.mint(address(vault), 1e18);
        uint256 availableYield = 1e18 - vault.yieldBuffer();
        uint256 availableMinusFee = (availableYield * (1e9 - 1e8)) / 1e9;
        assertEq(vault.liquidatableBalanceOf(address(underlyingAsset)), availableMinusFee);
    }

    /* ============ transferTokensOut ============ */

    function testTransferTokensOut_noFee() public {
        vault.setYieldFeePercentage(0); // no fee
        vault.setYieldFeeRecipient(bob);
        vault.setLiquidationPair(address(this));

        underlyingAsset.mint(address(vault), 1e18);
        uint256 amountOut = vault.liquidatableBalanceOf(address(underlyingAsset));
        assertGt(amountOut, 0);

        vm.expectEmit();
        emit Transfer(address(vault), alice, amountOut);

        vault.transferTokensOut(address(0), alice, address(underlyingAsset), amountOut);

        assertEq(underlyingAsset.balanceOf(alice), amountOut);
        assertEq(underlyingAsset.balanceOf(bob), 0);
    }

    // Fee is set, but recipient is the zero address, so no fee should be transferred
    function testTransferTokensOut_noFeeSinceFeeRecipientZero() public {
        vault.setYieldFeePercentage(1e8); // 10% fee
        vault.setYieldFeeRecipient(address(0));
        vault.setLiquidationPair(address(this));

        underlyingAsset.mint(address(vault), 1e18);
        uint256 amountOut = vault.liquidatableBalanceOf(address(underlyingAsset));
        assertGt(amountOut, 0);

        vm.expectEmit();
        emit Transfer(address(vault), alice, amountOut);

        vault.transferTokensOut(address(0), alice, address(underlyingAsset), amountOut);

        assertEq(underlyingAsset.balanceOf(alice), amountOut);
        assertEq(underlyingAsset.balanceOf(address(0)), 0);
    }

    function testTransferTokensOut_withFee() public {
        vault.setYieldFeePercentage(1e8); // 10% fee
        vault.setYieldFeeRecipient(bob);
        vault.setLiquidationPair(address(this));

        underlyingAsset.mint(address(vault), 1e18);
        uint256 amountOut = vault.liquidatableBalanceOf(address(underlyingAsset));
        uint256 yieldFee = 1e18 - vault.yieldBuffer() - amountOut;
        assertGt(amountOut, 0);

        vm.expectEmit();
        emit Transfer(address(vault), alice, amountOut);

        vm.expectEmit();
        emit Transfer(address(vault), bob, yieldFee);

        vault.transferTokensOut(address(0), alice, address(underlyingAsset), amountOut);

        assertEq(underlyingAsset.balanceOf(alice), amountOut);
        assertEq(underlyingAsset.balanceOf(bob), yieldFee);

        assertEq(amountOut / yieldFee, (1e9 - 1e8) / 1e8); // ratio of (amountOut : yieldFee) equal to (1 - feePercentage : feePercentage) 
    }

    function testTransferTokensOut_CallerNotLP() public {
        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(PrizeVault.CallerNotLP.selector, bob, vault.liquidationPair()));
        vault.transferTokensOut(address(0), bob, address(underlyingAsset), 0);
        vm.stopPrank();
    }

    function testTransferTokensOut_LiquidationTokenOutNotAsset() public {
        vm.startPrank(vault.liquidationPair());
        vm.expectRevert(abi.encodeWithSelector(PrizeVault.LiquidationTokenOutNotAsset.selector, address(vault), address(underlyingAsset)));
        vault.transferTokensOut(address(0), bob, address(vault), 0);
        vm.stopPrank();
    }

    function testTransferTokensOut_LiquidationAmountOutZero() public {
        vm.startPrank(vault.liquidationPair());
        vm.expectRevert(abi.encodeWithSelector(PrizeVault.LiquidationAmountOutZero.selector));
        vault.transferTokensOut(address(0), bob, address(underlyingAsset), 0);
        vm.stopPrank();
    }

    function testTransferTokensOut_LiquidationExceedsAvailable() public {
        vault.setYieldFeePercentage(0); // no fee
        vault.setLiquidationPair(address(this));

        underlyingAsset.mint(address(vault), 1e18);
        uint256 amountOut = vault.liquidatableBalanceOf(address(underlyingAsset));
        assertGt(amountOut, 0);

        vm.expectRevert(abi.encodeWithSelector(PrizeVault.LiquidationExceedsAvailable.selector, amountOut + 1, amountOut));
        vault.transferTokensOut(address(0), bob, address(underlyingAsset), amountOut + 1);
    }

    /* ============ verifyTokensIn ============ */

    function testVerifyTokensIn() public {
        prizeToken.mint(address(prizePool), 1e18);
        vm.startPrank(vault.liquidationPair());

        vm.expectEmit();
        emit MockContribute(address(vault), 1e18);
        vault.verifyTokensIn(address(prizeToken), 1e18, "");

        vm.stopPrank();
    }

    function testVerifyTokensIn_CallerNotLP() public {
        prizeToken.mint(address(prizePool), 1e18);
        vm.startPrank(bob);

        vm.expectRevert(abi.encodeWithSelector(PrizeVault.CallerNotLP.selector, bob, vault.liquidationPair()));
        vault.verifyTokensIn(address(prizeToken), 1e18, "");

        vm.stopPrank();
    }

    function testVerifyTokensIn_LiquidationTokenInNotPrizeToken() public {
        prizeToken.mint(address(prizePool), 1e18);
        vm.startPrank(vault.liquidationPair());

        vm.expectRevert(abi.encodeWithSelector(PrizeVault.LiquidationTokenInNotPrizeToken.selector, address(underlyingAsset), address(prizeToken)));
        vault.verifyTokensIn(address(underlyingAsset), 1e18, "");

        vm.stopPrank();
    }

}