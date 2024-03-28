// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";

import { HookManagerWrapper, HookManager, PrizeHooks } from "../contracts/wrapper/HookManagerWrapper.sol";
import { IPrizeHooks } from "../../src/interfaces/IPrizeHooks.sol";

contract HookManagerTest is Test {

    // Events:
    event SetHooks(address indexed account, PrizeHooks hooks);

    HookManagerWrapper hookManager;

    address alice;
    address bob;

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        hookManager = new HookManagerWrapper();
    }

    /* ============ setHooks ============ */

    function testSetHooks() public {
        PrizeHooks memory beforeHooks = hookManager.getHooks(alice);
        PrizeHooks memory newHooks = PrizeHooks(true, true, IPrizeHooks(address(this)));
        assertNotEq(hashHooks(beforeHooks), hashHooks(newHooks));

        vm.startPrank(alice);

        vm.expectEmit();
        emit SetHooks(alice, newHooks);
        hookManager.setHooks(newHooks);
        
        vm.stopPrank();

        PrizeHooks memory actualHooks = hookManager.getHooks(alice);

        assertEq(hashHooks(newHooks), hashHooks(actualHooks));
    }

    /* ============ getHooks ============ */

    function testGetHooks_Empty() public {
        PrizeHooks memory hooks = hookManager.getHooks(alice);
        PrizeHooks memory emptyHooks = PrizeHooks(false, false, IPrizeHooks(address(0)));
        assertEq(hashHooks(hooks), hashHooks(emptyHooks));
    }

    /* ============ helpers ============ */

    function hashHooks(PrizeHooks memory hooks) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(
            hooks.useBeforeClaimPrize,
            hooks.useAfterClaimPrize,
            hooks.implementation
        ));
    }

}