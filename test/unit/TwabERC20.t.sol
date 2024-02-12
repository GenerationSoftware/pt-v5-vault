// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Test, stdError } from "forge-std/Test.sol";

import { TwabERC20Wrapper, TwabERC20 } from "../contracts/wrapper/TwabERC20Wrapper.sol";
import { TwabController } from "pt-v5-twab-controller/TwabController.sol";

contract TwabERC20Test is Test {

    // Events
    event Transfer(address indexed from, address indexed to, uint256 amount);

    TwabERC20Wrapper public twabToken;

    TwabController public twabController;

    uint32 periodLength = 1 days;
    uint32 periodOffset = 0;

    address alice;
    address bob;

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        twabController = new TwabController(periodLength, periodOffset);
        twabToken = new TwabERC20Wrapper("TWAB Token", "TWAB", twabController);
    }

    /* ============ Constructor ============ */

    function testConstructor_TwabControllerZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(TwabERC20.TwabControllerZeroAddress.selector));
        new TwabERC20("", "", TwabController(address(0)));
    }

    function testConstructor_twabControllerSet() public {
        assertEq(address(twabToken.twabController()), address(twabController));
    }

    function testConstructor_nameSet() public {
        assertEq(twabToken.name(), "TWAB Token");
    }

    function testConstructor_symbolSet() public {
        assertEq(twabToken.symbol(), "TWAB");
    }

    /* ============ balanceOf ============ */

    function testBalanceOf_startingBalanceZero() public {
        assertEq(twabToken.balanceOf(address(this)), 0);
    }

    /* ============ totalSupply ============ */

    function testBalanceOf_startingSupplyZero() public {
        assertEq(twabToken.totalSupply(), 0);
    }

    /* ============ mint ============ */

    function testMint_updatesBalance() public {
        assertEq(twabToken.balanceOf(alice), 0);
        twabToken.mint(alice, 1e18);
        assertEq(twabToken.balanceOf(alice), 1e18);
        twabToken.mint(alice, 2e18 + 1);
        assertEq(twabToken.balanceOf(alice), 3e18 + 1);
    }

    function testMint_updatesSupply() public {
        assertEq(twabToken.totalSupply(), 0);
        twabToken.mint(alice, 1e18);
        assertEq(twabToken.totalSupply(), 1e18);
        twabToken.mint(bob, 1);
        assertEq(twabToken.totalSupply(), 1e18 + 1);
    }

    function testMint_emitsTransfer() public {
        vm.expectEmit();
        emit Transfer(address(0), alice, 1);
        twabToken.mint(alice, 1);
    }

    /* ============ burn ============ */

    function testBurn_updatesBalance() public {
        assertEq(twabToken.balanceOf(alice), 0);
        twabToken.mint(alice, 1e18);
        assertEq(twabToken.balanceOf(alice), 1e18);
        twabToken.burn(alice, 1);
        assertEq(twabToken.balanceOf(alice), 1e18 - 1);
    }

    function testBurn_updatesSupply() public {
        assertEq(twabToken.totalSupply(), 0);
        twabToken.mint(alice, 1e18);
        twabToken.mint(bob, 1e18);
        assertEq(twabToken.totalSupply(), 2e18);
        twabToken.burn(bob, 1e18 - 1);
        assertEq(twabToken.totalSupply(), 1e18 + 1);
    }

    function testBurn_emitsTransfer() public {
        twabToken.mint(alice, 1);
        vm.expectEmit();
        emit Transfer(alice, address(0), 1);
        twabToken.burn(alice, 1);
    }

    /* ============ transfer ============ */

    function testTransfer_updatesBalances() public {
        twabToken.mint(alice, 1e18);
        assertEq(twabToken.balanceOf(alice), 1e18);
        assertEq(twabToken.balanceOf(bob), 0);
        vm.startPrank(alice);
        twabToken.transfer(bob, 4e17);
        vm.stopPrank();
        assertEq(twabToken.balanceOf(alice), 6e17);
        assertEq(twabToken.balanceOf(bob), 4e17);
    }

    function testTransfer_noChangeToSupply() public {
        twabToken.mint(alice, 1e18);
        twabToken.mint(bob, 1e18);
        assertEq(twabToken.totalSupply(), 2e18);
        vm.startPrank(alice);
        twabToken.transfer(bob, 5e17);
        vm.stopPrank();
        assertEq(twabToken.totalSupply(), 2e18);
    }

    function testTransfer_emitsTransfer() public {
        twabToken.mint(alice, 1);
        vm.expectEmit();
        emit Transfer(alice, bob, 1);
        vm.startPrank(alice);
        twabToken.transfer(bob, 1);
        vm.stopPrank();
    }

    /* ============ uint96 limiter ============ */

    function testLimitUint96() public {
        assertEq(twabToken.balanceOf(alice), 0);
        assertEq(twabToken.totalSupply(), 0);

        twabToken.mint(alice, type(uint96).max);
        
        assertEq(twabToken.balanceOf(alice), type(uint96).max);
        assertEq(twabToken.totalSupply(), type(uint96).max);

        vm.expectRevert(stdError.arithmeticError);
        twabToken.mint(alice, 1);

        vm.startPrank(alice);
        twabToken.transfer(bob, type(uint96).max);
        vm.stopPrank();

        assertEq(twabToken.balanceOf(alice), 0);
        assertEq(twabToken.balanceOf(bob), type(uint96).max);
        assertEq(twabToken.totalSupply(), type(uint96).max);

        vm.startPrank(bob);
        twabToken.transfer(alice, type(uint96).max / 2);
        vm.stopPrank();

        assertEq(twabToken.balanceOf(alice), type(uint96).max / 2);
        assertEq(twabToken.balanceOf(bob), type(uint96).max / 2 + 1);
        assertEq(twabToken.totalSupply(), type(uint96).max);

        twabToken.burn(alice, type(uint96).max / 2);
        twabToken.burn(bob, type(uint96).max / 2 + 1);

        assertEq(twabToken.balanceOf(alice), 0);
        assertEq(twabToken.balanceOf(bob), 0);
        assertEq(twabToken.totalSupply(), 0);
    }

}