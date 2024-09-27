// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseIntegration, IERC20, IERC4626 } from "../BaseIntegration.t.sol";

contract YearnV3ArbUsdce1IntegrationTest is BaseIntegration {
    uint256 fork;
    uint256 forkBlock = 257937555;
    uint256 forkBlockTimestamp = 1727451973;

    address internal _asset = address(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);
    address internal _assetWhale = address(0x25681Ab599B4E2CEea31F8B498052c53FC2D74db);
    address internal _yieldVault = address(0xDa3b69a45797DCA697Ff5bB2c10682f14373c063);

    /* ============ setup ============ */

    function setUpUnderlyingAsset() public virtual override returns (IERC20 asset, uint8 decimals, uint256 approxAssetUsdExchangeRate) {
        return (IERC20(_asset), 6, 1e18);
    }

    function setUpYieldVault() public virtual override returns (IERC4626) {
        return IERC4626(_yieldVault);
    }

    function setUpFork() public virtual override {
        fork = vm.createFork(vm.rpcUrl("arbitrum"), forkBlock);
        vm.selectFork(fork);
        vm.warp(forkBlockTimestamp);
    }

    function beforeSetup() public virtual override {
        lowGasPriceEstimate = 0.05 gwei;
        ignoreLoss = true;
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

    /// @dev Accrues yield by letting time pass
    function _accrueYield() internal virtual override prankception(_assetWhale) {
        vm.warp(block.timestamp + 1 days); // let 1 day pass by
    }

    /// @dev Yearn does not socialize losses automatically and instead realizes the loss when an account withdraws.
    /// If there is any loss on the yearn vault, the prize vault may not be able to withdraw until the yearn vault
    /// manager manually triggers the realization of loss through a harvestAndReport or similar call.
    function _simulateLoss() internal virtual override prankception(_yieldVault) {
        
    }

}