// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseIntegration, IERC20, IERC4626 } from "../BaseIntegration.t.sol";

contract AngleArbSteurIntegrationTest is BaseIntegration {
    uint256 fork;
    uint256 forkBlock = 206123461;
    uint256 forkBlockTimestamp = 1714415683;

    address internal _asset = address(0xFA5Ed56A203466CbBC2430a43c66b9D8723528E7);
    address internal _assetWhale = address(0xE4D9FaDDd9bcA5D8393BeE915dC56E916AB94d27);
    address internal _yieldVault = address(0x004626A008B1aCdC4c74ab51644093b155e59A23);

    /* ============ setup ============ */

    function setUpUnderlyingAsset() public virtual override returns (IERC20 asset, uint8 decimals, uint256 approxAssetUsdExchangeRate) {
        return (IERC20(_asset), 18, 1.07e18);
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
        lowGasPriceEstimate = 0.05 gwei; // just L2 gas, we ignore L1 costs for a super low estimate
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

    /// @dev Transfer tokens to the yield vault
    function _accrueYield() internal virtual override prankception(_assetWhale) {
        dealAssets(_yieldVault, 10 ** assetDecimals);
    }

    /// @dev Transfer tokens out of the yield vault
    function _simulateLoss() internal virtual override prankception(_yieldVault) {
        underlyingAsset.transfer(_assetWhale, underlyingAsset.balanceOf(_yieldVault) / 2); // transfer assets out of the yield vault
    }

}