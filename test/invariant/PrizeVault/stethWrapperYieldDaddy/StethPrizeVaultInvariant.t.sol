// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { console2 } from "forge-std/console2.sol";
import { PrizeVaultInvariant } from "../PrizeVaultInvariant.t.sol";
import { StethPrizeVaultFuzzHarness, PrizeVault } from "./StethPrizeVaultFuzzHarness.sol";

/// @dev This contract runs tests in a scenario where the yield vault can never lose funds (strictly increasing).
contract StethPrizeVaultInvariant is PrizeVaultInvariant {

    uint256 mainnetFork;
    uint256 forkBlock = 20636046;
    uint256 forkBlockTimestamp = 1724956295;

    address wrappedSteth = address(0xF9A98A9452485ed55cd3Ce5260C2b71c9807b11a);

    StethPrizeVaultFuzzHarness public aaveVaultHarness;

    function setUp() external override {
        // optimism fork:
        mainnetFork = vm.createFork(vm.rpcUrl("mainnet"), forkBlock);
        vm.selectFork(mainnetFork);

        vm.warp(forkBlockTimestamp);
        aaveVaultHarness = new StethPrizeVaultFuzzHarness(wrappedSteth, 1e5);
        vaultHarness = StethPrizeVaultFuzzHarness(aaveVaultHarness);
        targetContract(address(aaveVaultHarness));
        assertEq(vaultHarness.currentTime(), forkBlockTimestamp);

        // send some assets to cover initial yield buffer
        vm.startPrank(aaveVaultHarness.stethWhale());
        aaveVaultHarness.steth().transfer(address(aaveVaultHarness.vault()), 1e5);
        vm.stopPrank();
    }

}