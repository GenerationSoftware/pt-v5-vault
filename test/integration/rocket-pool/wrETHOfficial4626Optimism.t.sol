// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.24;

// import { BaseIntegration, IERC20, IERC4626 } from "../BaseIntegration.t.sol";
// import { WRETH, IERC20 as RETH_IERC20 } from "rETHERC4626/WRETH.sol";
// import { RETHERC4626 } from "rETHERC4626/RETHERC4626.sol";
// import { MockOracle } from "rETHERC4626/mock/MockOracle.sol";

// /**
//  * Note that the imports must be modified in `RETHERC4626.sol` to compile this test:
//  * import "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol";
//  * import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
//  * import {IWRETH} from "./interface/IWRETH.sol";
//  * 
//  * This file has been commented out to prevent builds from failing. If you would like to
//  * run this test, select all, then apply the import modifications listed above.
//  */

// contract wrETHOfficial4626OptimismIntegrationTest is BaseIntegration {
//     uint256 fork;
//     uint256 forkBlock = 122853185;
//     uint256 forkBlockTimestamp = 1721305147;

//     address internal _reth = address(0x9Bcef72be871e61ED4fBbc7630889beE758eb81D);
//     address internal _rethWhale = address(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
//     address internal _wrethWhale;

//     MockOracle internal _oracle;
//     WRETH internal _wreth;
//     RETHERC4626 internal _yieldVault;

//     /* ============ setup ============ */

//     function setUpUnderlyingAsset() public virtual override returns (IERC20 asset, uint8 decimals, uint256 approxAssetUsdExchangeRate) {
//         _oracle = new MockOracle(1 ether); // setup oracle for rETH with initial price at 1 ETH
//         _wreth = new WRETH(RETH_IERC20(_reth), _oracle);
//         return (IERC20(address(_wreth)), 18, 3.4e18);
//     }

//     function setUpYieldVault() public virtual override returns (IERC4626) {
//         _yieldVault = new RETHERC4626(_wreth);

//         _wrethWhale = makeAddr("wrethWhale");
//         vm.startPrank(_rethWhale);
//         IERC20(_reth).approve(address(_wreth), type(uint256).max);
//         _wreth.mint(IERC20(_reth).balanceOf(_rethWhale));
//         _wreth.transfer(_wrethWhale, _wreth.balanceOf(_rethWhale));
//         require(_wreth.balanceOf(_wrethWhale) > 0, "no wreth balance");
//         vm.stopPrank();

//         return IERC4626(address(_yieldVault));
//     }

//     function setUpFork() public virtual override {
//         fork = vm.createFork(vm.rpcUrl("optimism"), forkBlock);
//         vm.selectFork(fork);
//         vm.warp(forkBlockTimestamp);
//     }

//     function beforeSetup() public virtual override {
//         lowGasPriceEstimate = 0.05 gwei; // just L2 gas, we ignore L1 costs for a super low estimate
//         roundingErrorOnTransfer = 1; // 1 wei rounding error on transfer is common with wrETH
//     }

//     function afterSetup() public virtual override { }

//     /* ============ helpers to override ============ */

//     /// @dev The max amount of assets than can be dealt.
//     function maxDeal() public virtual override returns (uint256) {
//         return _wreth.balanceOf(_wrethWhale);
//     }

//     /// @dev May revert if the amount requested exceeds the amount available to deal.
//     function dealAssets(address to, uint256 amount) public virtual override prankception(_wrethWhale) {
//         _wreth.transfer(to, amount);
//     }

//     /// @dev Accrues yield by increasing the oracle price
//     function _accrueYield() internal virtual override {
//         uint256 _rate = _oracle.rate();
//         _oracle.setRate((_rate * (1e18 + (uint256(0.03e18) / 365))) / 1e18); // approx daily rate increase for 3% APR 
//         _wreth.rebase();
//     }

//     /// @dev Simulates loss by decreasing the oracle price
//     function _simulateLoss() internal virtual override {
//         uint256 _rate = _oracle.rate();
//         _oracle.setRate(_rate / 2);
//         _wreth.rebase();
//     }

// }