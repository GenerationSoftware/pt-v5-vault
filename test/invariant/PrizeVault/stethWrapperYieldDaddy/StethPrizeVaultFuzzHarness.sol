// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { PrizeVaultFuzzHarness, IERC4626, IERC20, PrizeVault, PrizePool } from "../PrizeVaultFuzzHarness.sol";

contract StethPrizeVaultFuzzHarness is PrizeVaultFuzzHarness {

    IERC20 public steth = IERC20(address(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84));
    address public stethWhale = address(0x93c4b944D05dfe6df7645A86cd2206016c51564D);

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
            owner, // owner
            address(0)
        );
    }

    /* ============ Asset Helpers ============ */

    function _dealAssets(address to, uint256 amount) internal override {
        (,address callerBefore,) = vm.readCallers();
        vm.stopPrank();

        vm.prank(stethWhale);
        steth.transfer(to, amount);

        (,address callerNow,) = vm.readCallers();
        if (callerNow != callerBefore) {
            vm.startPrank(callerBefore); // restart prank
        }
    }

    function _maxDealAssets() internal view override returns(uint256) {
        return steth.balanceOf(stethWhale);
    }

    /* ============ Yield Helpers ============ */

    function accrueYield(int88 yield) public override useCurrentTime {
        // yield accrues over time, so no need to mint it
        // we use `accrueTimeBasedYield` instead
    }

    function accrueTimeBasedYield(uint256 secondsPassed) public useCurrentTime {
        secondsPassed = _bound(secondsPassed, 1, 7 days); // max 7 days passed, min 1 second
        uint256 startBalance = yieldVault.totalAssets();
        setCurrentTime(currentTime + secondsPassed);

        (bool success, bytes memory data) = address(steth).call(abi.encodeWithSignature("totalSupply()"));
        uint256 currentTotalSupply = abi.decode(data, (uint256));
        require(success, "failed to get totalSupply");
        vm.mockCall(address(steth), abi.encodeWithSignature("totalSupply()"), abi.encode((currentTotalSupply * (1e18 + 9.5e8 * secondsPassed)) / 1e18)); // ~3% APR

        uint256 endBalance = yieldVault.totalAssets();
        vm.assume(endBalance > startBalance);
    }

}