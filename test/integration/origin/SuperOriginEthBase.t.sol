// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { console2 } from "forge-std/console2.sol";

import { BaseIntegration, IERC20, IERC4626 } from "../BaseIntegration.t.sol";

/**
 * Issues Found:
 * - OETH has an issue where transferring a rebasing balance can sometimes result in a 1 or 2 wei rounding error in
 *   the receiver's resulting balance. For example, the `Transfer` event records 1e18, but the resulting balance is 
 *   1e18 - 1. This shouldn't cause any issues in the prize vault since it's built to deal with small rounding errors, 
 *   but it may cause issues with integrations built on top of the prize vault since it may receive less tokens than
 *   expected during a withdraw or redeem. (https://github.com/OriginProtocol/origin-dollar/issues/1411#issuecomment-1536546728)
 */

contract SuperOriginEthBaseIntegrationTest is BaseIntegration {
    uint256 fork;
    uint256 forkBlock = 19914759;
    uint256 forkBlockTimestamp = 1726633265;

    address internal _asset = address(0xDBFeFD2e8460a6Ee4955A68582F85708BAEA60A3);
    address internal _assetWhale = address(0x86D888C3fA8A7F67452eF2Eccc1C5EE9751Ec8d6);
    address internal _yieldVault = address(0x7FcD174E80f264448ebeE8c88a7C4476AAF58Ea6);

    address internal _dripper = address(0x02f2C609950E90934ce99e58b4d7326aD0d7f8d6);

    /* ============ setup ============ */

    function setUpUnderlyingAsset() public virtual override returns (IERC20 asset, uint8 decimals, uint256 approxAssetUsdExchangeRate) {
        return (IERC20(_asset), 18, 3800e18); // approx 1 OETH for $3800
    }

    function setUpYieldVault() public virtual override returns (IERC4626) {
        return IERC4626(_yieldVault);
    }

    function setUpFork() public virtual override {
        fork = vm.createFork(vm.rpcUrl("base"), forkBlock);
        vm.selectFork(fork);
        vm.warp(forkBlockTimestamp);
    }

    function beforeSetup() public virtual override {
        lowGasPriceEstimate = 0.5 gwei;
        assetPrecisionLoss = 1; // loses 1 decimal of precision due to extra 1-wei rounding errors on transfer
        roundingErrorOnTransfer = 1; // loses 1 wei on asset transfer
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

    /// @dev Accrues yield by letting time pass and calling the dripper
    function _accrueYield() internal virtual override {
        vm.warp(block.timestamp + 1 days);
        (bool success,) = _dripper.call(abi.encodeWithSignature("collectAndRebase()"));
        require(success, "drip not successful");
    }

    /// @dev Loss simulated by transferring assets out of the yield vault
    function _simulateLoss() internal virtual override prankception(_yieldVault) {
        IERC20(_asset).transfer(_assetWhale, IERC4626(_yieldVault).totalAssets() / 2); // 50% loss
    }

}