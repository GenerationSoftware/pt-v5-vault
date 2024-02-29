// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { PrizeVaultFuzzHarness } from "./PrizeVaultFuzzHarness.sol";

contract LossyPrizeVaultFuzzHarness is PrizeVaultFuzzHarness {

    constructor (uint256 _yieldBuffer) PrizeVaultFuzzHarness(_yieldBuffer) { }

    /// @dev Overwrite the yield accrual so that assets are either minted or burned
    function accrueYield(int88 yield) public override useCurrentTime {
        if (yield > 0) {
            _dealAssets(address(yieldVault), uint256(uint88(yield)));
        } else if (yield < 0) {
            uint256 yieldVaultBalance = underlyingAsset.balanceOf(address(yieldVault));
            if (uint256(uint88(yield * -1)) > yieldVaultBalance) {
                yield = int88(uint88(yieldVaultBalance)) * -1;
            }
            underlyingAsset.burn(address(yieldVault), uint256(uint88(yield)));
        }
    }

}