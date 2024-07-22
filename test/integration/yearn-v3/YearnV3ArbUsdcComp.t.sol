// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseIntegration, IERC20, IERC4626 } from "../BaseIntegration.t.sol";

contract YearnV3ArbUsdcCompIntegrationTest is BaseIntegration {
    uint256 fork;
    uint256 forkBlock = 233833534;
    uint256 forkBlockTimestamp = 1721391662;

    address internal _asset = address(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);
    address internal _assetWhale = address(0x2Df1c51E09aECF9cacB7bc98cB1742757f163dF7);
    address internal _yieldVault = address(0xCACc53bAcCe744ac7b5C1eC7eb7e3Ab01330733b);
    address internal _cToken = address(0x9c4ec768c28520B50860ea7a15bd7213a9fF58bf);
    address internal _keeper = address(0xE0D19f6b240659da8E87ABbB73446E7B4346Baee);

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
    /// We transfer some yield bearing tokens out of the yield vault and then report the results.
    function _simulateLoss() internal virtual override prankception(_yieldVault) {
        IERC20(_cToken).transfer(_assetWhale, IERC20(_cToken).balanceOf(_yieldVault) / 2);
        _report();
    }

    /* ============ yearn helpers ============ */

    function _report() internal prankception(_keeper) {
        (bool success,) = _yieldVault.call(abi.encodeWithSignature("report()"));
        require(success, "report failed");
    }

}