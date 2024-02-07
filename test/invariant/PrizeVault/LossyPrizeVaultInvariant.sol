// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Test } from "forge-std/Test.sol";
import { LossyPrizeVaultFuzzHarness } from "./LossyPrizeVaultFuzzHarness.sol";

/// @dev This contract runs tests in a scenario where the yield vault can gain or lose funds and checks that the
/// expected lossy behaviors are adhered to.
contract LossyPrizeVaultInvariant is Test {
    LossyPrizeVaultFuzzHarness public lossyVaultHarness;

    function setUp() external {
        lossyVaultHarness = new LossyPrizeVaultFuzzHarness(1e5);
        targetContract(address(lossyVaultHarness));
    }

    function invariantDisableDepositsOnLoss() external {
        uint256 totalAssets = lossyVaultHarness.vault().totalAssets();
        uint256 totalDebt = lossyVaultHarness.vault().totalDebt();
        uint256 totalSupply = lossyVaultHarness.vault().totalSupply();
        if (totalDebt > totalAssets || type(uint96).max - totalSupply == 0) {
            assertEq(lossyVaultHarness.vault().maxDeposit(address(this)), 0);
        } else {
            assertGt(lossyVaultHarness.vault().maxDeposit(address(this)), 0);
        }
    }

    function invariantNoYieldWhenDebtExceedsAssets() external {
        uint256 totalAssets = lossyVaultHarness.vault().totalAssets();
        uint256 totalDebt = lossyVaultHarness.vault().totalDebt();
        if (totalDebt >= totalAssets) {
            assertEq(lossyVaultHarness.vault().liquidatableBalanceOf(address(lossyVaultHarness.underlyingAsset())), 0);
            assertEq(lossyVaultHarness.vault().liquidatableBalanceOf(address(lossyVaultHarness.vault())), 0);
            assertEq(lossyVaultHarness.vault().availableYieldBalance(), 0);
        }
    }
}