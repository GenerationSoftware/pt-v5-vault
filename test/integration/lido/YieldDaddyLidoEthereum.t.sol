// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { console2 } from "forge-std/console2.sol";

import { BaseIntegration, IERC20, IERC4626 } from "../BaseIntegration.t.sol";

/**
 * Issues Found:
 * - stETH has an issue where transferring a rebasing balance can sometimes result in a 1 or 2 wei rounding error in
 *   the receiver's resulting balance. For example, the `Transfer` event records 1e18, but the resulting balance is 
 *   1e18 - 1. This shouldn't cause any issues in the prize vault since it's built to deal with small rounding errors, 
 *   but it may cause issues with integrations built ontop of the prize vault since it may receive less tokens than
 *   expected during a withdraw or redeem. (https://github.com/lidofinance/lido-dao/issues/442)
 */

contract YieldDaddyLidoEthereumIntegrationTest is BaseIntegration {
    uint256 fork;
    uint256 forkBlock = 19311723;
    uint256 forkBlockTimestamp = 1708950275;

    address internal _asset = address(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    address internal _assetWhale = address(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
    address internal _yieldVault = address(0xF9A98A9452485ed55cd3Ce5260C2b71c9807b11a);
    address internal _reporter = address(0x1Ca0fEC59b86F549e1F1184d97cb47794C8Af58d);
    address internal _oracle = address(0x852deD011285fe67063a08005c71a85690503Cee);

    bytes internal constant _oracleCalldata = hex'fc7377cd000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000081dbbf0000000000000000000000000000000000000000000000000000000000051cca0000000000000000000000000000000000000000000000000022d0ce3854c07800000000000000000000000000000000000000000000000000000000000001e000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000136d6dc5e611456e00000000000000000000000000000000000000000000000009f8c8f905b5fc9e2a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000220000000000000000000000000000000000000000003be303e5898f9f73c73ee6d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000006b88';

    /* ============ setup ============ */

    function setUpUnderlyingAsset() public virtual override returns (IERC20 asset, uint8 decimals, uint256 approxAssetUsdExchangeRate) {
        return (IERC20(_asset), 18, uint256(1e18) / uint256(3000)); // approx 1 stETH for $3000
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
        lowGasPriceEstimate = 7 gwei;
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
    function _accrueYield() internal virtual override prankception(_reporter) {
        (bool success,) = _oracle.call(_oracleCalldata);
        // console2.log(block.number, "block number");
        // console2.log(block.timestamp, "block timestamp");
        require(success, "reward accrual failed");
        // vm.transact(forkTxHash);
        // vm.rollFork(19311732);
    }

    /// @dev Need to figure out how to simulate loss on the stETH exchange rate. Maybe by minting a bunch of tokens without collateral?
    function _simulateLoss() internal virtual override prankception(_yieldVault) {
        // TODO
    }

}