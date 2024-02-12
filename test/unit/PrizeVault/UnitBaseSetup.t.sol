// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Test } from "forge-std/Test.sol";
import { ERC20, IERC20, IERC4626 } from "openzeppelin/token/ERC20/extensions/ERC4626.sol";
import { ERC20Mock } from "openzeppelin/mocks/ERC20Mock.sol";

import { PrizePool } from "pt-v5-prize-pool/PrizePool.sol";
import { TwabController } from "pt-v5-twab-controller/TwabController.sol";

import { ERC20PermitMock } from "../../contracts/mock/ERC20PermitMock.sol";
import { LiquidationPairMock } from "../../contracts/mock/LiquidationPairMock.sol";
import { LiquidationRouterMock } from "../../contracts/mock/LiquidationRouterMock.sol";
import { PrizePoolMock } from "../../contracts/mock/PrizePoolMock.sol";
import { YieldVault } from "../../contracts/mock/YieldVault.sol";
import { Permit } from "../../contracts/utility/Permit.sol";

import { PrizeVaultWrapper, PrizeVault } from "../../contracts/wrapper/PrizeVaultWrapper.sol";

contract UnitBaseSetup is Test, Permit {

    /* ============ events ============ */

    event Deposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event ClaimerSet(address indexed claimer);
    event LiquidationPairSet(address indexed tokenOut, address indexed liquidationPair);
    event YieldFeeRecipientSet(address indexed yieldFeeRecipient);
    event YieldFeePercentageSet(uint256 yieldFeePercentage);
    event MockContribute(address prizeVault, uint256 amount);
    event ClaimYieldFeeShares(address indexed recipient, uint256 shares);
    event TransferYieldOut(address indexed liquidationPair, address indexed tokenOut, address indexed recipient, uint256 amountOut, uint256 yieldFee);
    event Sponsor(address indexed caller, uint256 assets, uint256 shares);

    /* ============ variables ============ */

    address internal owner;
    uint256 internal ownerPrivateKey;

    address internal alice;
    uint256 internal alicePrivateKey;

    address internal bob;
    uint256 internal bobPrivateKey;

    address public constant SPONSORSHIP_ADDRESS = address(1);

    PrizeVaultWrapper public vault;
    string public vaultName = "PoolTogether Test Vault";
    string public vaultSymbol = "pTest";

    YieldVault public yieldVault;
    ERC20PermitMock public underlyingAsset;
    ERC20PermitMock public prizeToken;
    LiquidationRouterMock public liquidationRouter;
    LiquidationPairMock public liquidationPair;

    address public claimer;
    PrizePoolMock public prizePool;

    uint32 public drawPeriodSeconds = 1 days;
    TwabController public twabController;

    /* ============ setup ============ */

    function setUpUnderlyingAsset() public virtual returns (ERC20PermitMock) {
        return new ERC20PermitMock("Dai Stablecoin");
    }

    function setUp() public virtual {
        (owner, ownerPrivateKey) = makeAddrAndKey("Owner");
        (alice, alicePrivateKey) = makeAddrAndKey("Alice");
        (bob, bobPrivateKey) = makeAddrAndKey("Bob");

        underlyingAsset = setUpUnderlyingAsset();
        prizeToken = new ERC20PermitMock("PoolTogether");

        twabController = new TwabController(1 hours, uint32(block.timestamp));

        prizePool = new PrizePoolMock(prizeToken, twabController);

        claimer = address(0xe291d9169F0316272482dD82bF297BB0a11D267f);

        yieldVault = new YieldVault(
            address(underlyingAsset),
            "Test Yield Vault",
            "yvTest"
        );

        vault = new PrizeVaultWrapper(
            vaultName,
            vaultSymbol,
            yieldVault,
            PrizePool(address(prizePool)),
            claimer,
            address(this),
            0,
            1e6,
            address(this)
        );

        liquidationPair = new LiquidationPairMock(
            address(vault),
            address(prizePool),
            address(prizeToken),
            address(vault)
        );

        liquidationRouter = new LiquidationRouterMock();
    }

    /* ============ helpers ============ */

    function _setLiquidationPair() internal {
        vault.setLiquidationPair(address(liquidationPair));
    }

    function _accrueYield(ERC20Mock _underlyingAsset, IERC4626 _yieldVault, uint256 _yield) internal {
        _underlyingAsset.mint(address(_yieldVault), _yield);
    }

    function _liquidate(
        LiquidationRouterMock _liquidationRouter,
        LiquidationPairMock _liquidationPair,
        IERC20 _prizeToken,
        uint256 _yield,
        address _user
    ) internal returns (uint256 userPrizeTokenBalanceBeforeSwap, uint256 prizeTokenContributed) {
        prizeTokenContributed = _liquidationPair.computeExactAmountIn(_yield);
        userPrizeTokenBalanceBeforeSwap = _prizeToken.balanceOf(_user);

        _prizeToken.approve(address(_liquidationRouter), prizeTokenContributed);
        _liquidationRouter.swapExactAmountOut(_liquidationPair, _user, _yield, prizeTokenContributed);
    }

}
