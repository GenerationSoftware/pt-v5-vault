// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { console2 } from "forge-std/console2.sol";
import { PrizeVaultInvariant } from "../PrizeVaultInvariant.t.sol";
import { AavePrizeVaultFuzzHarness, PrizeVault } from "./AavePrizeVaultFuzzHarness.sol";

/// @dev This contract runs tests in a scenario where the yield vault can never lose funds (strictly increasing).
contract AavePrizeVaultInvariant is PrizeVaultInvariant {

    uint256 optimismFork;
    uint256 forkBlock = 116075762;
    uint256 forkBlockTimestamp = 1707750301;

    address wrappedAaveUSDC = address(0x7624E0a373b8c77B07E5d5242fD7a194ecC9A4C6);

    AavePrizeVaultFuzzHarness public aaveVaultHarness;

    function setUp() external override {
        // optimism fork:
        optimismFork = vm.createFork(vm.rpcUrl("optimism"), forkBlock);
        vm.selectFork(optimismFork);

        vm.warp(forkBlockTimestamp);
        aaveVaultHarness = new AavePrizeVaultFuzzHarness(wrappedAaveUSDC, 1e5);
        vaultHarness = AavePrizeVaultFuzzHarness(aaveVaultHarness);
        targetContract(address(aaveVaultHarness));
        assertEq(vaultHarness.currentTime(), forkBlockTimestamp);

        // send some assets to cover initial yield buffer
        vm.startPrank(aaveVaultHarness.usdcWhale());
        aaveVaultHarness.usdc().transfer(address(aaveVaultHarness.vault()), 1e5);
        vm.stopPrank();
    }

}