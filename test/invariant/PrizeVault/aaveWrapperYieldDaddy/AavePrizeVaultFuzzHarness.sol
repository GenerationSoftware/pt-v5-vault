// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { PrizeVaultFuzzHarness, IERC4626, IERC20, PrizeVault, PrizePool } from "../PrizeVaultFuzzHarness.sol";

contract AavePrizeVaultFuzzHarness is PrizeVaultFuzzHarness {

    IERC20 public usdc = IERC20(address(0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85));
    address public usdcWhale = address(0xacD03D601e5bB1B275Bb94076fF46ED9D753435A);

    constructor (address _yieldVault, uint256 _yieldBuffer) PrizeVaultFuzzHarness(_yieldBuffer) {
        // override the yield vault, vault, and asset:
        yieldVault = IERC4626(_yieldVault);
        vault = new PrizeVault(
            vaultName,
            vaultSymbol,
            yieldVault,
            PrizePool(address(prizePool)),
            address(this), // changes as tests run
            address(this), // yield fee recipient (changes as tests run)
            0, // yield fee percent (changes as tests run)
            _yieldBuffer, // yield buffer
            owner // owner
        );
    }

    /* ============ Asset Helpers ============ */

    function _dealAssets(address to, uint256 amount) internal override {
        (,address callerBefore,) = vm.readCallers();
        vm.stopPrank();

        vm.prank(usdcWhale);
        usdc.transfer(to, amount);

        (,address callerNow,) = vm.readCallers();
        if (callerNow != callerBefore) {
            vm.startPrank(callerBefore); // restart prank
        }
    }

    function _maxDealAssets() internal view override returns(uint256) {
        return usdc.balanceOf(usdcWhale);
    }

    /* ============ Yield Helpers ============ */

    /// @dev Override the yield accrual for the aave vault implementation
    function accrueYield(int88 yield) public override useCurrentTime {
        // yield accrues over time, so no need to mint it
        // we use `accrueTimeBasedYield` instead
    }

    function accrueTimeBasedYield(uint256 secondsPassed) public useCurrentTime {
        secondsPassed = _bound(secondsPassed, 1, 7 days); // max 7 days passed, min 1 second
        uint256 startBalance = yieldVault.totalAssets();
        setCurrentTime(currentTime + secondsPassed);
        uint256 endBalance = yieldVault.totalAssets();
        vm.assume(endBalance > startBalance);
    }

}