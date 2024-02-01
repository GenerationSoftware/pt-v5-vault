// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Test } from "forge-std/Test.sol";

import { ERC20Mock } from "openzeppelin/mocks/ERC20Mock.sol";
import { IERC4626 } from "openzeppelin/token/ERC20/extensions/ERC4626.sol";

import { PrizePool } from "pt-v5-prize-pool/PrizePool.sol";
import { TwabController } from "pt-v5-twab-controller/TwabController.sol";

import { PrizeVaultFactory } from "../../../src/PrizeVaultFactory.sol";
import { PrizeVault } from "../../../src/PrizeVault.sol";
import { PrizePoolMock, IERC20 } from "../../contracts/mock/PrizePoolMock.sol";
import { YieldVault } from "../../contracts/mock/YieldVault.sol";

contract PrizeVaultFactoryTest is Test {

    /* ============ Events ============ */

    event NewPrizeVault(
        PrizeVault indexed vault,
        IERC4626 indexed yieldVault,
        PrizePool indexed prizePool,
        string name,
        string symbol
    );

    /* ============ Variables ============ */

    PrizeVaultFactory public vaultFactory;
    TwabController public twabController;
    YieldVault public yieldVault;
    ERC20Mock public asset;
    ERC20Mock public prizeToken;
    PrizePoolMock public prizePool;

    uint32 public yieldFeePercentage;
    uint256 public yieldBuffer;

    string public name;
    string public symbol;

    address public claimer;
    address public owner;

    /* ============ Setup ============ */

    function setUp() public {
        vaultFactory = new PrizeVaultFactory();
        twabController = TwabController(makeAddr("twabController"));
        asset = new ERC20Mock();
        yieldVault = new YieldVault(address(asset), "Yield Vault", "yv");
        prizeToken = new ERC20Mock();
        prizePool = new PrizePoolMock(prizeToken, twabController);

        yieldFeePercentage = 0;
        yieldBuffer = 1e6;

        name = "PoolTogether Test Vault";
        symbol = "pTest";

        claimer = makeAddr("claimer");
        owner = makeAddr("owner");
        
        vm.mockCall(
            address(yieldVault),
            abi.encodeWithSelector(IERC4626.asset.selector),
            abi.encode(address(asset))
        );
    }

    /* ============ deployVault ============ */

    function testDeployVault() external {
        PrizeVault _vault;

        // We don't know the vault address in advance, so we don't check topic 1
        vm.expectEmit(false, true, true, true);
        emit NewPrizeVault(PrizeVault(_vault), yieldVault, PrizePool(address(prizePool)), name, symbol);

        _vault = vaultFactory.deployVault(
            name,
            symbol,
            yieldVault,
            PrizePool(address(prizePool)),
            claimer,
            address(this),
            yieldFeePercentage,
            yieldBuffer,
            owner
        );

        assertEq(address(PrizeVault(_vault).asset()), address(asset));
        assertEq(PrizeVault(_vault).name(), name);
        assertEq(PrizeVault(_vault).symbol(), symbol);
        assertEq(address(PrizeVault(_vault).yieldVault()), address(yieldVault));
        assertEq(address(PrizeVault(_vault).prizePool()), address(prizePool));
        assertEq(PrizeVault(_vault).claimer(), claimer);
        assertEq(PrizeVault(_vault).yieldFeePercentage(), yieldFeePercentage);
        assertEq(PrizeVault(_vault).yieldBuffer(), yieldBuffer);
        assertEq(PrizeVault(_vault).owner(), owner);

        assertEq(vaultFactory.totalVaults(), 1);
        assertTrue(vaultFactory.deployedVaults(address(_vault)));
    }

    function testDeployVault_secondDeployShouldHaveDiffAddress() public {
        PrizeVault _vault1 = PrizeVault(
            vaultFactory.deployVault(
                name,
                symbol,
                yieldVault,
                PrizePool(address(prizePool)),
                claimer,
                address(this),
                yieldFeePercentage,
                yieldBuffer,
                owner
            )
        );

        PrizeVault _vault2 = PrizeVault(
            vaultFactory.deployVault(
                name,
                symbol,
                yieldVault,
                PrizePool(address(prizePool)),
                claimer,
                address(this),
                yieldFeePercentage,
                yieldBuffer,
                owner
            )
        );

        assertNotEq(address(_vault1), address(_vault2));
    }
}
