// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseIntegration, IERC20, IERC4626 } from "../BaseIntegration.t.sol";

// requires cancun

contract YearnV3ArbWeEthPtIntegrationTest is BaseIntegration {
    uint256 fork;
    uint256 forkBlock = 233833534;
    uint256 forkBlockTimestamp = 1721391662;

    address internal _asset = address(0x35751007a407ca6FEFfE80b3cB397736D2cf4dbe);
    address internal _assetWhale = address(0x8437d7C167dFB82ED4Cb79CD44B7a32A1dd95c77);
    address internal _yieldVault = address(0x044E75fCbF7BD3f8f4577FF317554e9c0037F145);
    address internal _yieldBearingToken = address(0xE43C0bbbfC34575927798B8Ba9d58AE58F2Be3C6);
    address internal _keeper = address(0x0A4d75AB96375E37211Cd00a842d77d0519eeD1B);

    /* ============ setup ============ */

    function setUpUnderlyingAsset() public virtual override returns (IERC20 asset, uint8 decimals, uint256 approxAssetUsdExchangeRate) {
        return (IERC20(_asset), 18, 3400e18);
    }

    function setUpYieldVault() public virtual override returns (IERC4626) {
        return IERC4626(_yieldVault);
    }

    function setUpFork() public virtual override {
        fork = vm.createFork(vm.rpcUrl("arbitrum"), forkBlock);
        vm.selectFork(fork);
        vm.warp(forkBlockTimestamp + 1 days);
    }

    function beforeSetup() public virtual override {
        lowGasPriceEstimate = 0.05 gwei;
        ignoreLoss = true; // simulating loss is complex for this strategy. It should behave similarly to the other v3 strategies once yearn realizes any loss by calling "report"
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
        dealAssets(_yieldBearingToken, maxDeal() / 1000); // deal some assets to the ybt contract
        _tend();
        _report();
    }

    /// @dev Yearn does not socialize losses automatically and instead realizes the loss when an account withdraws.
    /// If there is any loss on the yearn vault, the prize vault may not be able to withdraw until the yearn vault
    /// manager manually triggers the realization of loss through a harvestAndReport or similar call.
    function _simulateLoss() internal virtual override prankception(_yieldVault) {
        
    }

    /* ============ yearn helpers ============ */

    function _report() internal prankception(_keeper) {
        (bool success,) = _yieldVault.call(abi.encodeWithSignature("update_debt(address,uint256)", address(0xE43C0bbbfC34575927798B8Ba9d58AE58F2Be3C6), type(uint256).max));
        require(success, "report failed");
    }

    function _tend() internal prankception(address(0xE0D19f6b240659da8E87ABbB73446E7B4346Baee)) {
        (bool success,) = _yieldBearingToken.call(abi.encodeWithSignature("tend()"));
        require(success, "tend failed");
    }

}