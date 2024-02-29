// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";

import { HookManagerWrapper, HookManager, VaultHooks } from "../contracts/wrapper/HookManagerWrapper.sol";
import { IVaultHooks } from "../../src/interfaces/IVaultHooks.sol";

contract HookManagerTest is Test {

    // Events:
    event SetHooks(address indexed account, VaultHooks hooks);

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
        VaultHooks memory beforeHooks = hookManager.getHooks(alice);
        VaultHooks memory newHooks = VaultHooks(true, true, IVaultHooks(address(this)));
        assertNotEq(hashHooks(beforeHooks), hashHooks(newHooks));

        vm.startPrank(alice);

        vm.expectEmit();
        emit SetHooks(alice, newHooks);
        hookManager.setHooks(newHooks);
        
        vm.stopPrank();

        VaultHooks memory actualHooks = hookManager.getHooks(alice);

        assertEq(hashHooks(newHooks), hashHooks(actualHooks));
    }

    /* ============ getHooks ============ */

    function testGetHooks_Empty() public {
        VaultHooks memory hooks = hookManager.getHooks(alice);
        VaultHooks memory emptyHooks = VaultHooks(false, false, IVaultHooks(address(0)));
        assertEq(hashHooks(hooks), hashHooks(emptyHooks));
    }

    /* ============ helpers ============ */

    function hashHooks(VaultHooks memory hooks) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(
            hooks.useBeforeClaimPrize,
            hooks.useAfterClaimPrize,
            hooks.implementation
        ));
    }

}