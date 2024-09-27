// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { StdCheats } from "forge-std/StdCheats.sol";
import { StdUtils } from "forge-std/StdUtils.sol";

import { ERC20, IERC20, IERC4626 } from "openzeppelin/token/ERC20/extensions/ERC4626.sol";
import { IERC20Permit } from "openzeppelin/token/ERC20/extensions/draft-ERC20Permit.sol";
import { ERC20Mock } from "openzeppelin/mocks/ERC20Mock.sol";

import { PrizePool } from "pt-v5-prize-pool/PrizePool.sol";
import { TwabController } from "pt-v5-twab-controller/TwabController.sol";

import { ERC20PermitMock } from "../../contracts/mock/ERC20PermitMock.sol";
import { LiquidationPairMock } from "../../contracts/mock/LiquidationPairMock.sol";
import { LiquidationRouterMock } from "../../contracts/mock/LiquidationRouterMock.sol";
import { PrizePoolMock } from "../../contracts/mock/PrizePoolMock.sol";
import { YieldVault } from "../../contracts/mock/YieldVault.sol";
import { Permit } from "../../contracts/utility/Permit.sol";

import { PrizeVault } from "../../../src/PrizeVault.sol";

contract PrizeVaultFuzzHarness is Permit, StdCheats, StdUtils {

    event Deposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares);
    event Withdraw(
        address indexed sender,
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );

    /* ============ Variables ============ */

    address[] public actors;
    uint256[] public actorPrivateKeys;
    address public currentActor;
    uint256 public currentPrivateKey;

    address public owner;
    uint256 public ownerPrivateKey;

    address public alice;
    uint256 public alicePrivateKey;

    address public bob;
    uint256 public bobPrivateKey;

    address public joe;
    uint256 public joePrivateKey;

    PrizeVault public vault;
    string public vaultName = "PoolTogether Test Vault";
    string public vaultSymbol = "pTest";

    IERC4626 public yieldVault;
    ERC20PermitMock public underlyingAsset;
    ERC20PermitMock public prizeToken;

    PrizePoolMock public prizePool;
    TwabController public twabController;

    bytes32 private constant _PERMIT_TYPEHASH = keccak256(
        "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
    );

    uint256 totalAssetsLostToRoundingErrors;
    uint256 numWithdraws;
    uint256 numDeposits;

    uint256 public currentTime;

    /* ============ Time Warp Helpers ============ */

    modifier useCurrentTime() {
        vm.warp(currentTime);
        _;
    }

    function setCurrentTime(uint256 newTime) internal {
        currentTime = newTime;
        vm.warp(currentTime);
    }

    /* ============ Constructor ============ */

    constructor(
        uint256 _yieldBuffer
    ) {
        (owner, ownerPrivateKey) = makeAddrAndKey("PrizeVaultOwner");
        (alice, alicePrivateKey) = makeAddrAndKey("Alice");
        (bob, bobPrivateKey) = makeAddrAndKey("Bob");
        (joe, joePrivateKey) = makeAddrAndKey("Joe");

        actors = new address[](4);
        actors[0] = owner;
        actors[1] = alice;
        actors[2] = bob;
        actors[3] = joe;

        actorPrivateKeys = new uint256[](4);
        actorPrivateKeys[0] = ownerPrivateKey;
        actorPrivateKeys[1] = alicePrivateKey;
        actorPrivateKeys[2] = bobPrivateKey;
        actorPrivateKeys[3] = joePrivateKey;

        underlyingAsset = new ERC20PermitMock("UnderlyingAsset");
        prizeToken = new ERC20PermitMock("PoolTogether");

        twabController = new TwabController(1 hours, uint32(block.timestamp));
        prizePool = new PrizePoolMock(prizeToken, twabController);

        yieldVault = new YieldVault(
            address(underlyingAsset),
            "Test Yield Vault",
            "yvTest"
        );

        vault = new PrizeVault(
            vaultName,
            vaultSymbol,
            yieldVault,
            PrizePool(address(prizePool)),
            address(this), // changes as tests run
            address(this), // yield fee recipient (changes as tests run)
            0, // yield fee percent (changes as tests run)
            _yieldBuffer, // yield buffer
            owner, // owner
            address(0)
        );

        setCurrentTime(block.timestamp);
    }

    /* ============ Asset Helpers ============ */

    function _dealAssets(address to, uint256 amount) internal virtual {
        underlyingAsset.mint(to, amount);
    }

    // Limited to uint128 since the yield vault math can't handle max uint256 assets and uint128 still exceeds
    // the max TWAB supply limit (uint96).
    function _maxDealAssets() internal virtual view returns(uint256) {
        return type(uint128).max - underlyingAsset.totalSupply();
    }

    /* ============ Actor Helpers ============ */

    function _actor(uint256 actorIndexSeed) internal view returns(address) {
        return actors[_bound(actorIndexSeed, 0, actors.length - 1)];
    }

    function _actorPrivateKey(uint256 actorIndexSeed) internal view returns(uint256) {
        return actorPrivateKeys[_bound(actorIndexSeed, 0, actorPrivateKeys.length - 1)];
    }

    modifier useActor(uint256 actorIndexSeed) {
        currentActor = _actor(actorIndexSeed);
        currentPrivateKey = _actorPrivateKey(actorIndexSeed);
        vm.startPrank(currentActor);
        _;
        vm.stopPrank();
    }

    /* ============ accrue yield ============ */

    /// @dev amount is limited to int88 to prevent too much yield from accruing over the test period
    function accrueYield(int88 yield) public virtual useCurrentTime {
        if (yield < 0) yield = yield * -1; // this harness assumes no loss in the yield vault
        uint256 boundedYield = _bound(uint256(uint88(yield)), 0, _maxDealAssets());
        _dealAssets(address(yieldVault), boundedYield);
    }

    /* ============ deposit directly to yield vault ============ */

    /// @dev This helps discover scenarios that are only possible when there are other owners of yield
    /// vault shares.
    function depositDirectToYieldVault(uint256 callerSeed, uint256 receiverSeed, uint256 assets) public useCurrentTime useActor(callerSeed) {
        assets = _bound(assets, 0, yieldVault.maxDeposit(currentActor));
        assets = _bound(assets, 0, _maxDealAssets()); // restrict max deposit further to prevent overflows on yield vault and token supply
        _dealAssets(currentActor, assets);
        IERC20(vault.asset()).approve(address(yieldVault), assets);

        vm.expectEmit();
        emit Deposit(currentActor, _actor(receiverSeed), assets, yieldVault.previewDeposit(assets));
        yieldVault.deposit(assets, _actor(receiverSeed));
    }

    /* ============ withdraw directly from yield vault ============ */

    /// @dev This helps discover scenarios that are only possible when there are other owners of yield
    /// vault shares.
    function withdrawDirectFromYieldVault(uint256 callerSeed, uint256 receiverSeed, uint256 assets) public useCurrentTime useActor(callerSeed) {
        assets = _bound(assets, 0, yieldVault.maxWithdraw(currentActor));

        vm.expectEmit();
        emit Withdraw(currentActor, _actor(receiverSeed), currentActor, assets, yieldVault.previewWithdraw(assets));
        yieldVault.withdraw(assets, _actor(receiverSeed), currentActor);
    }

    /* ============ transfer assets directly to vault on accident ============ */

    function transferAssetsToVaultOnAccident(uint256 fromSeed, uint256 assets) public useCurrentTime useActor(fromSeed) {
        assets = _bound(assets, 0, underlyingAsset.balanceOf(currentActor));
        underlyingAsset.transfer(address(vault), assets);
    }

    /* ============ transfer ============ */

    function transferShares(uint256 fromSeed, uint256 toSeed, uint256 amount) public useCurrentTime useActor(fromSeed) {
        amount = _bound(amount, 0, vault.balanceOf(currentActor));
        vault.transfer(_actor(toSeed), amount);
    }

    /* ============ deposit ============ */

    function deposit(uint256 callerSeed, uint256 receiverSeed, uint256 assets) public useCurrentTime useActor(callerSeed) {
        assets = _bound(assets, 0, vault.maxDeposit(currentActor));
        assets = _bound(assets, 0, _maxDealAssets());
        _dealAssets(currentActor, assets);
        IERC20(vault.asset()).approve(address(vault), assets);

        vm.expectEmit();
        emit Deposit(currentActor, _actor(receiverSeed), assets, vault.previewDeposit(assets));
        vault.deposit(assets, _actor(receiverSeed));
    }

    /* ============ mint ============ */

    function mint(uint256 callerSeed, uint256 receiverSeed, uint256 shares) public useCurrentTime useActor(callerSeed) {
        shares = _bound(shares, 0, vault.maxMint(currentActor));
        shares = _bound(shares, 0, _maxDealAssets());
        uint256 assets = vault.previewMint(shares); // use previewMint to get the amount of assets that will be taken
        _dealAssets(currentActor, assets);
        IERC20(vault.asset()).approve(address(vault), assets);

        vm.expectEmit();
        emit Deposit(currentActor, _actor(receiverSeed), vault.previewMint(assets), shares);
        vault.mint(shares, _actor(receiverSeed));
    }

    /* ============ withdraw ============ */

    function withdraw(uint256 assets, uint256 callerSeed, uint256 receiverSeed, uint256 ownerSeed) public useCurrentTime useActor(callerSeed) {
        assets = _bound(assets, 0, vault.maxWithdraw( _actor(ownerSeed)));
        uint256 shares = vault.previewWithdraw(assets);

        vm.startPrank( _actor(ownerSeed));
        vault.approve(currentActor, shares); // approve caller to spend shares
        vm.stopPrank();

        vm.expectEmit();
        emit Withdraw(currentActor, _actor(receiverSeed), _actor(ownerSeed), assets, shares);
        vault.withdraw(assets, _actor(receiverSeed),  _actor(ownerSeed));
    }

    /* ============ redeem ============ */

    function redeem(uint256 shares, uint256 callerSeed, uint256 receiverSeed, uint256 ownerSeed) public useCurrentTime useActor(callerSeed) {
        shares = _bound(shares, 0, vault.maxRedeem(_actor(ownerSeed)));
        uint256 assets = vault.previewRedeem(shares);

        vm.startPrank(_actor(ownerSeed));
        vault.approve(currentActor, shares); // approve caller to spend shares
        vm.stopPrank();

        vm.expectEmit();
        emit Withdraw(currentActor, _actor(receiverSeed), _actor(ownerSeed), assets, shares);
        vault.redeem(shares, _actor(receiverSeed), _actor(ownerSeed));
    }

    /* ============ depositWithPermit ============ */

    function depositWithPermit(uint256 callerSeed, uint256 ownerSeed, uint256 assets) public useCurrentTime useActor(ownerSeed) {
        assets = _bound(assets, 0, vault.maxDeposit(currentActor));
        assets = _bound(assets, 0, _maxDealAssets());
        _dealAssets(currentActor, assets);
        (uint8 _v, bytes32 _r, bytes32 _s) = _signPermit(
            underlyingAsset,
            vault,
            assets,
            currentActor,
            currentPrivateKey
        );
        
        // deposit with caller and owner signature
        vm.startPrank(_actor(callerSeed));
        if (_actor(callerSeed) != _actor(ownerSeed)) {
            vm.expectRevert(abi.encodeWithSelector(PrizeVault.PermitCallerNotOwner.selector, _actor(callerSeed), _actor(ownerSeed)));
        } else {
            vm.expectEmit();
            emit Deposit(_actor(callerSeed), _actor(ownerSeed), assets, vault.previewDeposit(assets));
        }
        vault.depositWithPermit(assets, currentActor, block.timestamp, _v, _r, _s);
        vm.stopPrank();
    }

    /* ============ claimYieldFeeShares ============ */

    function claimYieldFeeShares(uint256 callerSeed, uint256 shares) public useCurrentTime useActor(callerSeed) {
        shares = _bound(shares, 0, vault.yieldFeeBalance());
        if (currentActor != vault.yieldFeeRecipient()) {
            vm.expectRevert(abi.encodeWithSelector(PrizeVault.CallerNotYieldFeeRecipient.selector, currentActor, vault.yieldFeeRecipient()));
        }
        vault.claimYieldFeeShares(shares);
    }

    /* ============ transferTokensOut ============ */

    function transferTokensOut(uint256 callerSeed, uint256 receiverSeed, bool useAssetForTokenOut, uint256 amountOut) public useCurrentTime useActor(callerSeed) {
        address tokenOut = address(vault); // share token
        if (useAssetForTokenOut) {
            tokenOut = address(underlyingAsset); // asset token
        }
        amountOut = _bound(amountOut, 0, vault.liquidatableBalanceOf(tokenOut));
        if (currentActor != vault.liquidationPair()) {
            vm.expectRevert(abi.encodeWithSelector(PrizeVault.CallerNotLP.selector, currentActor, vault.liquidationPair()));
        }
        vault.transferTokensOut(address(0), _actor(receiverSeed), tokenOut, amountOut);
    }

    /* ============ verifyTokensIn ============ */

    /// @dev amountIn is uint88 to ensure we don't mint too many prize tokens over the course of the tests.
    function verifyTokensIn(uint88 amountIn, uint256 callerSeed) public useCurrentTime useActor(callerSeed) {
        prizeToken.mint(address(prizePool), amountIn);
        if (currentActor != vault.liquidationPair()) {
            vm.expectRevert(abi.encodeWithSelector(PrizeVault.CallerNotLP.selector, currentActor, vault.liquidationPair()));
        }
        vault.verifyTokensIn(address(prizeToken), amountIn, "");
    }

    /* ============ setLiquidationPair ============ */

    function setLiquidationPair(uint256 callerSeed, uint256 lpAddressSeed) public useCurrentTime useActor(callerSeed) {
        if (currentActor != vault.owner()) {
            vm.expectRevert("Ownable/caller-not-owner");
        }
        vault.setLiquidationPair(_actor(lpAddressSeed));
    }

    /* ============ setYieldFeePercentage ============ */

    function setYieldFeePercentage(uint256 callerSeed, uint256 yieldFeePercentage) public useCurrentTime useActor(callerSeed) {
        yieldFeePercentage = _bound(yieldFeePercentage, 0, vault.MAX_YIELD_FEE());
        if (currentActor != vault.owner()) {
            vm.expectRevert("Ownable/caller-not-owner");
        }
        vault.setYieldFeePercentage(uint32(yieldFeePercentage));
    }

    /* ============ setYieldFeeRecipient ============ */

    function setYieldFeeRecipient(uint256 callerSeed, uint256 yieldFeeRecipientSeed) public useCurrentTime useActor(callerSeed) {
        if (currentActor != vault.owner()) {
            vm.expectRevert("Ownable/caller-not-owner");
        }
        vault.setYieldFeeRecipient(_actor(yieldFeeRecipientSeed));
    }

}