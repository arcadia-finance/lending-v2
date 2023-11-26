/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { LendingPoolGuardian_Fuzz_Test, BaseGuardian, GuardianErrors } from "./_LendingPoolGuardian.fuzz.t.sol";

import { GuardianErrors } from "../../../../lib/accounts-v2/src/libraries/Errors.sol";

/**
 * @notice Fuzz tests for the function "pause" of contract "LendingPoolGuardian".
 */
contract Pause_LendingPoolGuardian_Fuzz_Test is LendingPoolGuardian_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LendingPoolGuardian_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_pause_OnlyGuard(address nonGuard) public {
        vm.assume(nonGuard != users.guardian);

        vm.startPrank(nonGuard);
        vm.expectRevert(GuardianErrors.OnlyGuardian.selector);
        lendingPoolGuardian.pause();
        vm.stopPrank();
    }

    function testFuzz_Revert_pause_TimeNotExpired(uint256 lastPauseTimestamp, uint256 timePassed) public {
        lastPauseTimestamp = bound(lastPauseTimestamp, 32 days + 1, type(uint32).max);
        timePassed = bound(timePassed, 0, 32 days);

        // Given: A random "lastPauseTimestamp".
        vm.warp(lastPauseTimestamp);
        vm.prank(users.guardian);
        lendingPoolGuardian.pause();

        // Given: less than 32 days passed
        vm.warp(lastPauseTimestamp + timePassed);

        // When: Guardian pauses again within 32 days passed from the last pause.
        // Then: The transaction reverts.
        vm.startPrank(users.guardian);
        vm.expectRevert(GuardianErrors.CoolDownPeriodNotPassed.selector);
        lendingPoolGuardian.pause();
        vm.stopPrank();
    }

    function testFuzz_Success_pause(uint256 lastPauseTimestamp, uint256 timePassed, Flags memory initialFlags) public {
        lastPauseTimestamp = bound(lastPauseTimestamp, 32 days + 1, type(uint32).max - 32 days - 1);
        timePassed = bound(timePassed, 32 days + 1, type(uint32).max);

        // Given: A random "lastPauseTimestamp".
        vm.warp(lastPauseTimestamp);
        vm.prank(users.guardian);
        lendingPoolGuardian.pause();

        // And: Flags are in random state.
        setFlags(initialFlags);

        // Given: More than 32 days passed.
        vm.warp(lastPauseTimestamp + timePassed);

        // When: the Guardian pauses.
        vm.startPrank(users.guardian);
        vm.expectEmit(true, true, true, true);
        emit PauseFlagsUpdated(true, true, true, true, true);
        lendingPoolGuardian.pause();
        vm.stopPrank();

        // Then: All flags are set to True.
        assertTrue(lendingPoolGuardian.repayPaused());
        assertTrue(lendingPoolGuardian.withdrawPaused());
        assertTrue(lendingPoolGuardian.borrowPaused());
        assertTrue(lendingPoolGuardian.depositPaused());
        assertTrue(lendingPoolGuardian.liquidationPaused());
    }
}
