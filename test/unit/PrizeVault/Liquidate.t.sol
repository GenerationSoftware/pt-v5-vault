// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ERC20Mock } from "openzeppelin/mocks/ERC20Mock.sol";
import { IERC4626 } from "openzeppelin/token/ERC20/extensions/ERC4626.sol";
import { IERC20, UnitBaseSetup, PrizeVault, YieldVault, IERC4626 } from "./UnitBaseSetup.t.sol";

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
        assertEq(vault.liquidatableBalanceOf(address(vault)), 1e18 - vault.yieldBuffer());
    }

    function testLiquidatableBalanceOf_withFee() public {
        vault.setYieldFeePercentage(1e8); // 10%

        underlyingAsset.mint(address(vault), 1e18);
        uint256 availableYield = 1e18 - vault.yieldBuffer();
        uint256 availableMinusFee = (availableYield * (1e9 - 1e8)) / 1e9;

        assertEq(vault.liquidatableBalanceOf(address(underlyingAsset)), availableMinusFee);
        assertEq(vault.liquidatableBalanceOf(address(vault)), availableMinusFee);
    }

    function testLiquidatableBalanceOf_respectsMaxAssetWithdraw() public {
        vault.setYieldFeePercentage(0); // no fee

        // make a small deposit to mint some shares on yield vault
        underlyingAsset.mint(address(alice), 1e18);
        vm.startPrank(alice);
        underlyingAsset.approve(address(vault), 1e18);
        vault.deposit(1e18, alice);
        vm.stopPrank();

        // mint yield to yield vault
        underlyingAsset.mint(address(yieldVault), 1e18);
        uint256 availableYield = vault.availableYieldBalance();
        assertApproxEqAbs(availableYield, 1e18 - vault.yieldBuffer(), 1);

        vm.mockCall(
            address(yieldVault),
            abi.encodeWithSelector(IERC4626.maxWithdraw.selector, address(vault)),
            abi.encode(availableYield / 2) // less than available yield, so we shouldn't be able to liquidate more than this
        );

        assertEq(vault.liquidatableBalanceOf(address(underlyingAsset)), availableYield / 2);
    }

    function testLiquidatableBalanceOf_respectsMaxShareMint() public {
        vault.setYieldFeePercentage(0); // no fee

        uint256 supplyCapLeft = 100;

        // make a large deposit to use most of the shares:
        underlyingAsset.mint(address(alice), type(uint96).max);
        vm.startPrank(alice);
        underlyingAsset.approve(address(vault), type(uint96).max - supplyCapLeft);
        vault.deposit(type(uint96).max - supplyCapLeft, alice);
        vm.stopPrank();

        underlyingAsset.mint(address(vault), 1e18);
        uint256 availableYield = vault.availableYieldBalance();
        assertApproxEqAbs(availableYield, 1e18 - vault.yieldBuffer(), 1);

        assertLt(supplyCapLeft, availableYield);

        assertEq(vault.liquidatableBalanceOf(address(vault)), supplyCapLeft); // less than available yield since shares are capped at uint96 max
    }

    /* ============ transferTokensOut ============ */

    function testTransferTokensOut_noFee() public {
        vault.setYieldFeePercentage(0); // no fee
        vault.setYieldFeeRecipient(bob);
        vault.setLiquidationPair(address(this));

        // test with asset and then vault shares
        uint256 snapshot = vm.snapshot();
        address tokenOut = address(underlyingAsset);
        address tokenFrom = address(vault);
        for (uint i = 0; i < 2; i++) {
            if (i == 1) {
                vm.revertTo(snapshot);
                tokenOut = address(vault);
                tokenFrom = address(0); // minted
            }

            underlyingAsset.mint(address(vault), 1e18);
            uint256 amountOut = vault.liquidatableBalanceOf(address(tokenOut));
            assertGt(amountOut, 0);

            vm.expectEmit();
            emit Transfer(tokenFrom, alice, amountOut);

            vm.expectEmit();
            emit TransferYieldOut(address(this), tokenOut, alice, amountOut, 0);

            vault.transferTokensOut(address(0), alice, address(tokenOut), amountOut);

            assertEq(IERC20(tokenOut).balanceOf(alice), amountOut);
            assertEq(vault.yieldFeeBalance(), 0);
        }
    }

    // Fee is set, but recipient is the zero address, so no fee should be transferred
    function testTransferTokensOut_noFeeSinceFeeRecipientZero() public {
        vault.setYieldFeePercentage(1e8); // 10% fee
        vault.setYieldFeeRecipient(address(0));
        vault.setLiquidationPair(address(this));

        // test with asset and then vault shares
        uint256 snapshot = vm.snapshot();
        address tokenOut = address(underlyingAsset);
        address tokenFrom = address(vault);
        for (uint i = 0; i < 2; i++) {
            if (i == 1) {
                vm.revertTo(snapshot);
                tokenOut = address(vault);
                tokenFrom = address(0); // minted
            }

            underlyingAsset.mint(address(vault), 1e18);
            uint256 amountOut = vault.liquidatableBalanceOf(tokenOut);
            assertGt(amountOut, 0);

            vm.expectEmit();
            emit Transfer(tokenFrom, alice, amountOut);

            vm.expectEmit();
            emit TransferYieldOut(address(this), tokenOut, alice, amountOut, 0);

            vault.transferTokensOut(address(0), alice, tokenOut, amountOut);

            assertEq(IERC20(tokenOut).balanceOf(alice), amountOut);
            assertEq(vault.yieldFeeBalance(), 0);
        }
    }

    function testTransferTokensOut_withFee() public {
        vault.setYieldFeePercentage(1e8); // 10% fee
        vault.setYieldFeeRecipient(bob);
        vault.setLiquidationPair(address(this));

        // test with asset and then vault shares
        uint256 snapshot = vm.snapshot();
        address tokenOut = address(underlyingAsset);
        address tokenFrom = address(vault);
        for (uint i = 0; i < 2; i++) {
            if (i == 1) {
                vm.revertTo(snapshot);
                tokenOut = address(vault);
                tokenFrom = address(0); // minted
            }

            underlyingAsset.mint(address(vault), 1e18);
            uint256 amountOut = vault.liquidatableBalanceOf(tokenOut);
            uint256 yieldFee = 1e18 - vault.yieldBuffer() - amountOut;
            assertGt(amountOut, 0);

            vm.expectEmit();
            emit Transfer(tokenFrom, alice, amountOut);

            vm.expectEmit();
            emit TransferYieldOut(address(this), tokenOut, alice, amountOut, yieldFee);

            vault.transferTokensOut(address(0), alice, tokenOut, amountOut);

            assertEq(IERC20(tokenOut).balanceOf(alice), amountOut);
            assertEq(vault.yieldFeeBalance(), yieldFee);

            assertEq(amountOut / yieldFee, (1e9 - 1e8) / 1e8); // ratio of (amountOut : yieldFee) equal to (1 - feePercentage : feePercentage) 
        }
    }

    function testTransferTokensOut_CallerNotLP() public {
        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(PrizeVault.CallerNotLP.selector, bob, vault.liquidationPair()));
        vault.transferTokensOut(address(0), bob, address(underlyingAsset), 0);
        vm.stopPrank();
    }

    function testTransferTokensOut_LiquidationTokenOutNotSupported() public {
        underlyingAsset.mint(address(vault), 1e18);
        vm.startPrank(vault.liquidationPair());
        vm.expectRevert(abi.encodeWithSelector(PrizeVault.LiquidationTokenOutNotSupported.selector, alice));
        vault.transferTokensOut(address(0), bob, alice, 1);
        vm.stopPrank();
    }

    function testTransferTokensOut_LiquidationAmountOutZero() public {
        vm.startPrank(vault.liquidationPair());

        vm.expectRevert(abi.encodeWithSelector(PrizeVault.LiquidationAmountOutZero.selector));
        vault.transferTokensOut(address(0), bob, address(underlyingAsset), 0);

        vm.expectRevert(abi.encodeWithSelector(PrizeVault.LiquidationAmountOutZero.selector));
        vault.transferTokensOut(address(0), bob, address(vault), 0);

        vm.stopPrank();
    }

    function testTransferTokensOut_LiquidationExceedsAvailable() public {
        vault.setYieldFeePercentage(0); // no fee
        vault.setLiquidationPair(address(this));

        underlyingAsset.mint(address(vault), 1e18);

        // assets
        uint256 amountOut = vault.liquidatableBalanceOf(address(underlyingAsset));
        assertGt(amountOut, 0);
        vm.expectRevert(abi.encodeWithSelector(PrizeVault.LiquidationExceedsAvailable.selector, amountOut + 1, amountOut));
        vault.transferTokensOut(address(0), bob, address(underlyingAsset), amountOut + 1);

        // vault shares
        amountOut = vault.liquidatableBalanceOf(address(vault));
        assertGt(amountOut, 0);
        vm.expectRevert(abi.encodeWithSelector(PrizeVault.LiquidationExceedsAvailable.selector, amountOut + 1, amountOut));
        vault.transferTokensOut(address(0), bob, address(vault), amountOut + 1);
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

    /* ============ claimYieldFeeShares ============ */

    function testClaimYieldFeeShares_CallerNotYieldFeeRecipient() public {
        vault.setYieldFeeRecipient(bob);

        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(PrizeVault.CallerNotYieldFeeRecipient.selector, alice, bob));
        vault.claimYieldFeeShares(100);
        vm.stopPrank();
    }

    function testClaimYieldFeeShares_MintZeroShares() public {
        vault.setYieldFeeRecipient(address(this));
        vm.expectRevert(abi.encodeWithSelector(PrizeVault.MintZeroShares.selector));
        vault.claimYieldFeeShares(0);
    }

    function testClaimYieldFeeShares_SharesExceedsYieldFeeBalance() public {
        vault.setYieldFeePercentage(1e8); // 10% fee
        vault.setYieldFeeRecipient(bob);
        vault.setLiquidationPair(address(this));

        // liquidate some yield
        underlyingAsset.mint(address(vault), 1e18);
        uint256 amountOut = vault.liquidatableBalanceOf(address(underlyingAsset));
        assertGt(amountOut, 0);

        vault.transferTokensOut(address(0), alice, address(underlyingAsset), amountOut);
        uint256 yieldFeeBalance = vault.yieldFeeBalance();
        assertGt(yieldFeeBalance, 0);
        
        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(PrizeVault.SharesExceedsYieldFeeBalance.selector, yieldFeeBalance + 1, yieldFeeBalance));
        vault.claimYieldFeeShares(yieldFeeBalance + 1);
        vm.stopPrank();
    }

    function testClaimYieldFeeShares_withdrawFullBalance() public {
        vault.setYieldFeePercentage(1e8); // 10% fee
        vault.setYieldFeeRecipient(bob);
        vault.setLiquidationPair(address(this));

        // liquidate some yield
        underlyingAsset.mint(address(vault), 1e18);
        uint256 amountOut = vault.liquidatableBalanceOf(address(underlyingAsset));
        assertGt(amountOut, 0);

        vault.transferTokensOut(address(0), alice, address(underlyingAsset), amountOut);
        uint256 yieldFeeBalance = vault.yieldFeeBalance();
        assertGt(yieldFeeBalance, 0);
        
        vm.startPrank(bob);
        vm.expectEmit();
        emit Transfer(address(0), bob, yieldFeeBalance);
        vm.expectEmit();
        emit ClaimYieldFeeShares(bob, yieldFeeBalance);
        vault.claimYieldFeeShares(yieldFeeBalance);
        vm.stopPrank();

        assertEq(vault.balanceOf(bob), yieldFeeBalance);
    }

    function testClaimYieldFeeShares_withdrawPartialBalance() public {
        vault.setYieldFeePercentage(1e8); // 10% fee
        vault.setYieldFeeRecipient(bob);
        vault.setLiquidationPair(address(this));

        // liquidate some yield
        underlyingAsset.mint(address(vault), 1e18);
        uint256 amountOut = vault.liquidatableBalanceOf(address(underlyingAsset));
        assertGt(amountOut, 0);

        vault.transferTokensOut(address(0), alice, address(underlyingAsset), amountOut);
        uint256 yieldFeeBalance = vault.yieldFeeBalance();
        assertGt(yieldFeeBalance, 0);
        
        vm.startPrank(bob);
        vm.expectEmit();
        emit Transfer(address(0), bob, yieldFeeBalance / 3);
        vm.expectEmit();
        emit ClaimYieldFeeShares(bob, yieldFeeBalance / 3);
        vault.claimYieldFeeShares(yieldFeeBalance / 3);
        vm.stopPrank();

        assertEq(vault.balanceOf(bob), yieldFeeBalance / 3);
    }

}