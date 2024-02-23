// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { BaseIntegration, IERC20, IERC4626 } from "../BaseIntegration.t.sol";

contract SDaiEthereumTest is BaseIntegration {
    uint256 fork;
    uint256 forkBlock = 19284702;
    uint256 forkBlockTimestamp = 1708623756;

    address internal _asset = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    address internal _assetWhale = address(0x075e72a5eDf65F0A5f44699c7654C1a76941Ddc8);
    address internal _yieldVault = address(0x83F20F44975D03b1b09e64809B757c47f942BEeA);
    address internal _daiJoin = address(0x9759A6Ac90977b93B58547b4A71c78317f391A28);
    address internal _daiPot = address(0x197E90f9FAD81970bA7976f33CbD77088E5D7cf7);
    address internal _daiPotWard = address(0xBE8E3e3618f7474F8cB1d074A26afFef007E98FB);

    /* ============ setup ============ */

    function setUpUnderlyingAsset() public virtual override returns (IERC20 asset, uint8 decimals, uint256 approxAssetUsdExchangeRate) {
        return (IERC20(_asset), 18, 1e18);
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

    /// @dev Accrues yield by letting some time pass
    function _accrueYield() internal virtual override {
        vm.warp(block.timestamp + 1 days); // let 1 day pass by
    }

    /// @dev Simulates loss by exiting some DAI and transferring it out of the yield vault?
    // function _simulateLoss() internal virtual override prankception(_yieldVault) {
    //     uint256 exitAmount = yieldVault.totalAssets() / 2;
    //     (bool success1,) = _daiPot.call(abi.encodeWithSignature("exit(uint256)", exitAmount));
    //     assertEq(success1, true, "exited Pot successfully");
    //     (bool success2,) = _daiJoin.call(abi.encodeWithSignature("exit(address,uint256)", _assetWhale, exitAmount));
    //     assertEq(success2, true, "exited DaiJoin successfully");
    // }

    /// @dev Simulates loss by lowering the dsr below 1 and letting time pass?
    // function _simulateLoss() internal virtual override prankception(_daiPotWard) {
    //     (bool success1,) = _daiPot.call(abi.encodeWithSignature("drip()"));
    //     assertEq(success1, true, "updated rho");
    //     (bool success2,) = _daiPot.call(abi.encodeWithSignature("file(bytes32,uint256)", bytes32(0x6473720000000000000000000000000000000000000000000000000000000000), 1e27 - 1e22));
    //     assertEq(success2, true, "dsr lowered");
    //     vm.warp(block.timestamp + 10 days);
    // }

    function _simulateLoss() internal virtual override {
        revert("wat do?");
    }

}