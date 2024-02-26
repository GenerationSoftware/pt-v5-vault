// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { BaseIntegration, IERC20, IERC4626 } from "../BaseIntegration.t.sol";

contract SimpleTokenPoolIntegrationTest is BaseIntegration {
    uint256 fork;
    uint256 forkBlock = 116520679;
    uint256 forkBlockTimestamp = 1708640134;

    address internal _asset = address(0x395Ae52bB17aef68C2888d941736A71dC6d4e125);
    address internal _assetWhale = address(0xDB1FE6DA83698885104DA02A6e0b3b65c0B0dE80);
    address internal _yieldVault = address(0x8E142201FB15CBfDCcFd91Ed0b143143276eBaeB);

    /* ============ setup ============ */

    function setUpUnderlyingAsset() public virtual override returns (IERC20 asset, uint8 decimals, uint256 approxAssetUsdExchangeRate) {
        return (IERC20(_asset), 18, 3.3e18);
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

    /// @dev Accrues yield by sending assets to the yield vault
    function _accrueYield() internal virtual override prankception(_assetWhale) {
        dealAssets(_yieldVault, 10 ** assetDecimals);
    }

    /// @dev Simulates loss by transferring some liquid tokens out of the yield vault
    function _simulateLoss() internal virtual override prankception(_yieldVault) {
        underlyingAsset.transfer(_assetWhale, underlyingAsset.balanceOf(_yieldVault) / 2); // transfer assets out of the yield vault
    }

}