// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { console2 } from "forge-std/console2.sol";

import { BaseIntegration, IERC20, IERC4626 } from "../BaseIntegration.t.sol";

/**
 * Issues Found:
 * - stETH has an issue where transferring a rebasing balance can sometimes result in a 1 or 2 wei rounding error in
 *   the receiver's resulting balance. For example, the `Transfer` event records 1e18, but the resulting balance is 
 *   1e18 - 1. This shouldn't cause any issues in the prize vault since it's built to deal with small rounding errors, 
 *   but it may cause issues with integrations built on top of the prize vault since it may receive less tokens than
 *   expected during a withdraw or redeem. (https://github.com/lidofinance/lido-dao/issues/442)
 */

contract YieldDaddyLidoEthereumIntegrationTest is BaseIntegration {
    uint256 fork;
    uint256 forkBlock = 20636046;
    uint256 forkBlockTimestamp = 1724956295;

    address internal _asset = address(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    address internal _assetWhale = address(0x93c4b944D05dfe6df7645A86cd2206016c51564D);
    address internal _yieldVault = address(0xF9A98A9452485ed55cd3Ce5260C2b71c9807b11a);


    /* ============ setup ============ */

    function setUpUnderlyingAsset() public virtual override returns (IERC20 asset, uint8 decimals, uint256 approxAssetUsdExchangeRate) {
        return (IERC20(_asset), 18, 3800e18); // approx 1 stETH for $3800
    }

    function setUpYieldVault() public virtual override returns (IERC4626) {
        return IERC4626(_yieldVault);
    }

    function setUpFork() public virtual override {
        fork = vm.createFork(vm.rpcUrl("mainnet"), forkBlock);
        vm.selectFork(fork);
        vm.warp(forkBlockTimestamp);
    }

    function beforeSetup() public virtual override {
        lowGasPriceEstimate = 3 gwei;
        assetPrecisionLoss = 1; // loses 1 decimal of precision due to extra 1-wei rounding errors on transfer
        roundingErrorOnTransfer = 2; // loses 1-2 wei on asset transfer
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

    /// @dev Accrues yield by mocking the stETH total supply to be higher than it is
    function _accrueYield() internal virtual override prankception(_assetWhale) {
        (bool success, bytes memory data) = _asset.call(abi.encodeWithSignature("totalSupply()"));
        uint256 currentTotalSupply = abi.decode(data, (uint256));
        require(success, "failed to get totalSupply");
        vm.mockCall(_asset, abi.encodeWithSignature("totalSupply()"), abi.encode((currentTotalSupply * 1001) / 1000)); // 0.1% yield
    }

    /// @dev Loss simulated by mocking the stETH totalSupply to be lower than it is
    function _simulateLoss() internal virtual override prankception(_yieldVault) {
        (bool success, bytes memory data) = _asset.call(abi.encodeWithSignature("totalSupply()"));
        uint256 currentTotalSupply = abi.decode(data, (uint256));
        require(success, "failed to get totalSupply");
        vm.mockCall(_asset, abi.encodeWithSignature("totalSupply()"), abi.encode(currentTotalSupply / 2)); // 50% loss
    }

}