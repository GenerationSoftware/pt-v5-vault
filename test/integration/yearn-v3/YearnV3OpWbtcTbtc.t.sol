// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseIntegration, IERC20, IERC4626 } from "../BaseIntegration.t.sol";

contract YearnV3OpWbtcTbtcIntegrationTest is BaseIntegration {
    uint256 fork;
    uint256 forkBlock = 123760428;
    uint256 forkBlockTimestamp = 1723119633;

    address internal _asset = address(0x6e57B9E54ea043a829584B22182ad22bF446926C);
    address internal _assetWhale = address(0x14A9F3254046273E404fA164E85E9EF3d9c701ad);
    address internal _yieldVault = address(0xB34D380F284357B0E17173DE007F5e5e014f3167);

    /* ============ setup ============ */

    function setUpUnderlyingAsset() public virtual override returns (IERC20 asset, uint8 decimals, uint256 approxAssetUsdExchangeRate) {
        return (IERC20(_asset), 18, 11550000000e18);
    }

    function setUpYieldVault() public virtual override returns (IERC4626) {
        return IERC4626(_yieldVault);
    }

    function setUpFork() public virtual override {
        fork = vm.createFork(vm.rpcUrl("optimism"), forkBlock);
        vm.selectFork(fork);
        vm.warp(forkBlockTimestamp);
    }

    function beforeSetup() public virtual override {
        lowGasPriceEstimate = 0.05 gwei;
    }

    function afterSetup() public virtual override { }

    /* ============ helpers to override ============ */

    /// @dev The max amount of assets than can be dealt.
    function maxDeal() public virtual override returns (uint256) {
        return underlyingAsset.balanceOf(_assetWhale);
    }

    /// @dev May revert if the amount requested exceeds the amount available to deal.
    function dealAssets(address to, uint256 amount) public virtual override prankception(_assetWhale) {
        underlyingAsset.transfer(to, amount);
    }

    /// @dev 
    function _accrueYield() internal virtual override prankception(_assetWhale) {
        
    }

    /// @dev Yearn does not socialize losses automatically and instead realizes the loss when an account withdraws.
    /// If there is any loss on the yearn vault, the prize vault may not be able to withdraw until the yearn vault
    /// manager manually triggers the realization of loss through a harvestAndReport or similar call.
    function _simulateLoss() internal virtual override prankception(_yieldVault) {
        
    }

}