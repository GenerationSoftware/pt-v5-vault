// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test, Vm } from "forge-std/Test.sol";

import { ClaimableWrapper, Claimable, PrizePool } from "../contracts/wrapper/ClaimableWrapper.sol";
import { IPrizeHooks, PrizeHooks } from "../../src/interfaces/IPrizeHooks.sol";

contract ClaimableTest is Test, IPrizeHooks {

    // Expected Events:
    event ClaimerSet(address indexed claimer);

    // Custom Events:
    event BeforeClaimPrizeCalled(
        address winner,
        uint8 tier,
        uint32 prizeIndex,
        uint96 reward,
        address rewardRecipient
    );
    event AfterClaimPrizeCalled(
        address winner,
        uint8 tier,
        uint32 prizeIndex,
        uint256 prize,
        address prizeRecipient,
        bytes data
    );

    ClaimableWrapper claimable;
    IPrizeHooks hooks;

    PrizePool prizePool;

    address alice;
    address bob;
    address claimer;
    address prizeRedirectionAddress;

    bool useTooMuchGasBefore;
    bool useTooMuchGasAfter;
    bytes32 someBytes;

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        prizeRedirectionAddress = makeAddr("prizeRedirectionAddress");

        prizePool = PrizePool(makeAddr("prizePool"));
        claimer = address(this);

        claimable = new ClaimableWrapper(prizePool, claimer);
        hooks = this;

        useTooMuchGasBefore = false;
        useTooMuchGasAfter = false;
    }

    /* ============ constructor ============ */

    function testConstructor_setsPrizePool() public {
        ClaimableWrapper newClaimable = new ClaimableWrapper(prizePool, claimer);
        assertEq(address(newClaimable.prizePool()), address(prizePool));
    }

    function testConstructor_setsClaimer() public {
        vm.expectEmit();
        emit ClaimerSet(claimer);
        ClaimableWrapper newClaimable = new ClaimableWrapper(prizePool, claimer);
        assertEq(newClaimable.claimer(), claimer);
    }

    function testConstructor_PrizePoolZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(Claimable.PrizePoolZeroAddress.selector));
        new ClaimableWrapper(PrizePool(address(0)), claimer);
    }

    function testConstructor_ClaimerZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(Claimable.ClaimerZeroAddress.selector));
        new ClaimableWrapper(prizePool, address(0));
    }

    /* ============ setClaimer ============ */

    function testSetClaimer_setsClaimer() public {
        vm.expectEmit();
        emit ClaimerSet(alice);
        claimable.setClaimer(alice);
        assertEq(claimable.claimer(), alice);
    }

    function testSetClaimer_ClaimerZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(Claimable.ClaimerZeroAddress.selector));
        claimable.setClaimer(address(0));
    }

    /* ============ claimPrize ============ */

    function testClaimPrize_noHooksCalledByDefault() public {
        PrizeHooks memory aliceHooks = claimable.getHooks(alice);
        assertEq(aliceHooks.useBeforeClaimPrize, false);
        assertEq(aliceHooks.useAfterClaimPrize, false);

        mockClaimPrize(alice, 1, 2, alice, 1e17, bob);

        vm.recordLogs();
        claimable.claimPrize(alice, 1, 2, 1e17, bob);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Our test hook emits a log on each call, so if there were no logs, then the hooks were not called
        assertEq(logs.length, 0);
    }

    function testClaimPrize_beforeClaimPrizeHook() public {
        PrizeHooks memory beforeHookOnly = PrizeHooks(true, false, hooks);

        vm.startPrank(alice);
        claimable.setHooks(beforeHookOnly);
        vm.stopPrank();

        mockClaimPrize(alice, 1, 2, prizeRedirectionAddress, 1e17, bob);

        vm.expectEmit();
        emit BeforeClaimPrizeCalled(alice, 1, 2, 1e17, bob);

        vm.recordLogs();
        claimable.claimPrize(alice, 1, 2, 1e17, bob);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(logs.length, 1);
    }

    function testClaimPrize_afterClaimPrizeHook() public {
        PrizeHooks memory afterHookOnly = PrizeHooks(false, true, hooks);

        vm.startPrank(alice);
        claimable.setHooks(afterHookOnly);
        vm.stopPrank();

        mockClaimPrize(alice, 1, 2, alice, 1e17, bob);

        vm.expectEmit();
        emit AfterClaimPrizeCalled(alice, 1, 2, 9e17, alice, "");

        vm.recordLogs();
        claimable.claimPrize(alice, 1, 2, 1e17, bob);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        
        assertEq(logs.length, 1);
    }

    function testClaimPrize_bothHooks() public {
        PrizeHooks memory bothHooks = PrizeHooks(true, true, hooks);

        vm.startPrank(alice);
        claimable.setHooks(bothHooks);
        vm.stopPrank();

        mockClaimPrize(alice, 1, 2, prizeRedirectionAddress, 1e17, bob);

        vm.expectEmit();
        emit BeforeClaimPrizeCalled(alice, 1, 2, 1e17, bob);
        vm.expectEmit();
        emit AfterClaimPrizeCalled(alice, 1, 2, 9e17, prizeRedirectionAddress, "hook data");

        vm.recordLogs();
        claimable.claimPrize(alice, 1, 2, 1e17, bob);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        
        assertEq(logs.length, 2);
    }

    function testClaimPrize_ClaimRecipientZeroAddress() public {
        PrizeHooks memory beforeHookOnly = PrizeHooks(true, false, hooks);

        vm.startPrank(alice);
        claimable.setHooks(beforeHookOnly);
        vm.stopPrank();

        prizeRedirectionAddress = address(0); // zero address recipient

        mockClaimPrize(alice, 1, 2, prizeRedirectionAddress, 1e17, bob);

        vm.expectRevert(
            abi.encodeWithSelector(Claimable.ClaimRecipientZeroAddress.selector)
        );
        claimable.claimPrize(alice, 1, 2, 1e17, bob);
    }

    function testClaimPrize_CallerNotClaimer() public {
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(Claimable.CallerNotClaimer.selector, alice, claimer));
        claimable.claimPrize(alice, 1, 2, 1e17, bob);
        vm.stopPrank();
    }

    function testClaimPrize_returnsPrizeTotal() public {
        mockClaimPrize(alice, 1, 2, alice, 1e17, bob); // prizeTotal will be 10x reward (1e18)
        uint256 prizeTotal = claimable.claimPrize(alice, 1, 2, 1e17, bob);
        assertEq(prizeTotal, 1e18);

        mockClaimPrize(alice, 1, 2, alice, 3, bob); // prizeTotal will be 10x reward (30)
        uint256 prizeTotal2 = claimable.claimPrize(alice, 1, 2, 3, bob);
        assertEq(prizeTotal2, 30);
    }

    function testClaimPrize_beforeClaimPrizeHookTooMuchGas() public {
        PrizeHooks memory beforeHookOnly = PrizeHooks(true, false, hooks);

        vm.startPrank(alice);
        claimable.setHooks(beforeHookOnly);
        vm.stopPrank();

        mockClaimPrize(alice, 1, 2, prizeRedirectionAddress, 1e17, bob);

        useTooMuchGasBefore = true;

        vm.expectRevert();
        claimable.claimPrize(alice, 1, 2, 1e17, bob);
    }

    function testClaimPrize_afterClaimPrizeHookTooMuchGas() public {
        PrizeHooks memory afterHookOnly = PrizeHooks(true, false, hooks);

        vm.startPrank(alice);
        claimable.setHooks(afterHookOnly);
        vm.stopPrank();

        mockClaimPrize(alice, 1, 2, alice, 1e17, bob);

        useTooMuchGasAfter = true;

        vm.expectRevert();
        claimable.claimPrize(alice, 1, 2, 1e17, bob);
    }

    function testClaimPrize_bothHooksTooMuchGasAfter() public {
        PrizeHooks memory bothHooks = PrizeHooks(true, true, hooks);

        vm.startPrank(alice);
        claimable.setHooks(bothHooks);
        vm.stopPrank();

        mockClaimPrize(alice, 1, 2, prizeRedirectionAddress, 1e17, bob);

        useTooMuchGasAfter = true;

        vm.expectRevert();
        claimable.claimPrize(alice, 1, 2, 1e17, bob);
    }

    function testClaimPrize_beforeClaimPrize_ReturnDataOverLimit_hookData() public {
        bytes memory tooMuchHookData = new bytes(33); // 33 bytes of data

        // mock to return too much hook data
        vm.mockCall(
            address(this),
            abi.encodeWithSelector(
                IPrizeHooks.beforeClaimPrize.selector,
                alice, 1, 2, 1e17, bob
            ),
            abi.encode(alice, tooMuchHookData)
        );

        PrizeHooks memory bothHooks = PrizeHooks(true, true, hooks);

        vm.startPrank(alice);
        claimable.setHooks(bothHooks);
        vm.stopPrank();

        mockClaimPrize(alice, 1, 2, alice, 1e17, bob);

        // We expect a revert since the `beforeClaimPrize` function returns too much data
        vm.expectRevert(abi.encodeWithSelector(Claimable.ReturnDataOverLimit.selector, 160, 128)); // 5 words used, which is 32 bytes over the limit
        claimable.claimPrize(alice, 1, 2, 1e17, bob);
    }

    function testClaimPrize_beforeClaimPrize_ReturnDataOverLimit_onRevert() public {
        bytes memory tooMuchRevertData = new bytes(129); // 129 bytes of revert data

        // mock to revert with too much data
        vm.mockCallRevert(
            address(this),
            abi.encodeWithSelector(
                IPrizeHooks.beforeClaimPrize.selector,
                alice, 1, 2, 1e17, bob
            ),
            tooMuchRevertData
        );

        PrizeHooks memory beforeHookOnly = PrizeHooks(true, false, hooks);

        vm.startPrank(alice);
        claimable.setHooks(beforeHookOnly);
        vm.stopPrank();

        mockClaimPrize(alice, 1, 2, prizeRedirectionAddress, 1e17, bob);

        vm.expectRevert(abi.encodeWithSelector(Claimable.ReturnDataOverLimit.selector, 129, 128)); // 1 byte over the limit
        claimable.claimPrize(alice, 1, 2, 1e17, bob);
    }

    function testClaimPrize_afterClaimPrize_ReturnDataOverLimit_onRevert() public {
        bytes memory tooMuchRevertData = new bytes(129); // 129 bytes of revert data

        // mock to revert with too much data
        vm.mockCallRevert(
            address(this),
            abi.encodeWithSelector(
                IPrizeHooks.afterClaimPrize.selector,
                alice, 1, 2, 9e17, alice, ""
            ),
            tooMuchRevertData
        );

        PrizeHooks memory afterHookOnly = PrizeHooks(false, true, hooks);

        vm.startPrank(alice);
        claimable.setHooks(afterHookOnly);
        vm.stopPrank();

        mockClaimPrize(alice, 1, 2, alice, 1e17, bob);

        vm.expectRevert(abi.encodeWithSelector(Claimable.ReturnDataOverLimit.selector, 129, 128)); // 1 byte over the limit
        claimable.claimPrize(alice, 1, 2, 1e17, bob);
    }

    function testClaimPrize_beforeClaimPrize_bubblesRevertData() public {
        bytes memory maxRevertData = new bytes(128); // 128 bytes of revert data
        maxRevertData[0] = bytes1(0x01); // make the data non-zero

        // mock to revert with too much data
        vm.mockCallRevert(
            address(this),
            abi.encodeWithSelector(
                IPrizeHooks.beforeClaimPrize.selector,
                alice, 1, 2, 1e17, bob
            ),
            maxRevertData
        );

        PrizeHooks memory beforeHookOnly = PrizeHooks(true, false, hooks);

        vm.startPrank(alice);
        claimable.setHooks(beforeHookOnly);
        vm.stopPrank();

        mockClaimPrize(alice, 1, 2, prizeRedirectionAddress, 1e17, bob);

        vm.expectRevert(maxRevertData); // expected bubbled revert data
        claimable.claimPrize(alice, 1, 2, 1e17, bob);
    }

    function testClaimPrize_afterClaimPrize_bubblesRevertData() public {
        bytes memory maxRevertData = new bytes(128); // 128 bytes of revert data
        maxRevertData[0] = bytes1(0x01); // make the data non-zero

        // mock to revert with too much data
        vm.mockCallRevert(
            address(this),
            abi.encodeWithSelector(
                IPrizeHooks.afterClaimPrize.selector,
                alice, 1, 2, 9e17, alice, ""
            ),
            maxRevertData
        );

        PrizeHooks memory afterHookOnly = PrizeHooks(false, true, hooks);

        vm.startPrank(alice);
        claimable.setHooks(afterHookOnly);
        vm.stopPrank();

        mockClaimPrize(alice, 1, 2, alice, 1e17, bob);

        vm.expectRevert(maxRevertData); // expected bubbled revert data
        claimable.claimPrize(alice, 1, 2, 1e17, bob);
    }

    function testClaimPrize_beforeClaimPrize_bubblesEmptyRevertData() public {
        bytes memory emptyRevertData = new bytes(0); // 0 bytes

        // mock to revert with too much data
        vm.mockCallRevert(
            address(this),
            abi.encodeWithSelector(
                IPrizeHooks.beforeClaimPrize.selector,
                alice, 1, 2, 1e17, bob
            ),
            emptyRevertData
        );

        PrizeHooks memory beforeHookOnly = PrizeHooks(true, false, hooks);

        vm.startPrank(alice);
        claimable.setHooks(beforeHookOnly);
        vm.stopPrank();

        mockClaimPrize(alice, 1, 2, prizeRedirectionAddress, 1e17, bob);

        vm.expectRevert(emptyRevertData); // expected bubbled empty revert data
        claimable.claimPrize(alice, 1, 2, 1e17, bob);
    }

    function testClaimPrize_afterClaimPrize_bubblesEmptyRevertData() public {
        bytes memory emptyRevertData = new bytes(0); // 0 bytes

        // mock to revert with too much data
        vm.mockCallRevert(
            address(this),
            abi.encodeWithSelector(
                IPrizeHooks.afterClaimPrize.selector,
                alice, 1, 2, 9e17, alice, ""
            ),
            emptyRevertData
        );

        PrizeHooks memory afterHookOnly = PrizeHooks(false, true, hooks);

        vm.startPrank(alice);
        claimable.setHooks(afterHookOnly);
        vm.stopPrank();

        mockClaimPrize(alice, 1, 2, alice, 1e17, bob);

        vm.expectRevert(emptyRevertData); // expected bubbled empty revert data
        claimable.claimPrize(alice, 1, 2, 1e17, bob);
    }

    function testClaimPrize_beforeClaimPrize_noRevertOnMaxHookData() public {
        bytes memory maxHookData = new bytes(32); // 32 bytes of data

        // mock to return max hook data
        vm.mockCall(
            address(this),
            abi.encodeWithSelector(
                IPrizeHooks.beforeClaimPrize.selector,
                alice, 1, 2, 1e17, bob
            ),
            abi.encode(alice, maxHookData)
        );

        PrizeHooks memory bothHooks = PrizeHooks(true, true, hooks);

        vm.startPrank(alice);
        claimable.setHooks(bothHooks);
        vm.stopPrank();

        mockClaimPrize(alice, 1, 2, alice, 1e17, bob);

        // expect the after hook to be called with the max hook data with no issues
        vm.expectEmit();
        emit AfterClaimPrizeCalled(alice, 1, 2, 9e17, alice, maxHookData);
        claimable.claimPrize(alice, 1, 2, 1e17, bob);
    }

    function testClaimPrize_afterClaimPrize_ignoresHookData() public {
        bytes memory tooMuchHookData = new bytes(33); // 33 bytes of data

        // mock to return too much hook data
        vm.mockCall(
            address(this),
            abi.encodeWithSelector(
                IPrizeHooks.afterClaimPrize.selector,
                alice, 1, 2, 9e17, alice, ""
            ),
            abi.encode(alice, tooMuchHookData)
        );

        PrizeHooks memory afterHookOnly = PrizeHooks(false, true, hooks);

        vm.startPrank(alice);
        claimable.setHooks(afterHookOnly);
        vm.stopPrank();

        mockClaimPrize(alice, 1, 2, alice, 1e17, bob);

        // expect no revert even though the return data has been limited since the afterClaimPrize return data isn't used
        claimable.claimPrize(alice, 1, 2, 1e17, bob);
    }

    /* ============ IPrizeHooks Implementation ============ */

    function beforeClaimPrize(
        address winner,
        uint8 tier,
        uint32 prizeIndex,
        uint96 reward,
        address rewardRecipient
    ) external returns (address, bytes memory) {
        if (useTooMuchGasBefore) {
            for (uint i = 0; i < 1000; i++) {
                someBytes = keccak256(abi.encode(someBytes));
            }
        }
        emit BeforeClaimPrizeCalled(
            winner,
            tier,
            prizeIndex,
            reward,
            rewardRecipient
        );
        return (prizeRedirectionAddress, "hook data");
    }

    function afterClaimPrize(
        address winner,
        uint8 tier,
        uint32 prizeIndex,
        uint256 prize,
        address prizeRecipient,
        bytes memory data
    ) external {
        if (useTooMuchGasAfter) {
            for (uint i = 0; i < 1000; i++) {
                someBytes = keccak256(abi.encode(someBytes));
            }
        }
        emit AfterClaimPrizeCalled(
            winner,
            tier,
            prizeIndex,
            prize,
            prizeRecipient,
            data
        );
    }

    /// @dev Mocks a prize claim and returns a prize size of 10 times the claim reward
    function mockClaimPrize(
        address _winner,
        uint8 _tier,
        uint32 _prizeIndex,
        address _recipient,
        uint96 _reward,
        address _rewardRecipient
    ) public {
        vm.mockCall(
            address(prizePool),
            abi.encodeWithSelector(
                PrizePool.claimPrize.selector,
                _winner,
                _tier,
                _prizeIndex,
                _recipient,
                _reward,
                _rewardRecipient
            ),
            abi.encode(_reward * 10)
        );
    }

}