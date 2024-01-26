/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { LendingPoolGuardian_Fuzz_Test, BaseGuardian, GuardianErrors } from "./_LendingPoolGuardian.fuzz.t.sol";

import { GuardianErrors } from "../../../../lib/accounts-v2/src/libraries/Errors.sol";

/**
 * @notice Fuzz tests for the function "unPause" of contract "LendingPoolGuardian".
 */
contract UnPause_WithoutArgs_LendingPoolGuardian_Fuzz_Test is LendingPoolGuardian_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LendingPoolGuardian_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_unPause_TimeNotExpired(uint256 lastPauseTimestamp, uint256 timePassed, address sender)
        public
    {
        lastPauseTimestamp = bound(lastPauseTimestamp, 32 days + 1, type(uint32).max);
        timePassed = bound(timePassed, 0, 30 days);

        // Given: A random "lastPauseTimestamp".
        vm.warp(lastPauseTimestamp);
        vm.prank(users.guardian);
        lendingPoolGuardian.pause();

        // Given: less than 30 days passed
        vm.warp(lastPauseTimestamp + timePassed);

        // When: A sender un-pauses within 30 days passed from the last pause.
        // Then: The transaction reverts.
        vm.startPrank(sender);
        vm.expectRevert(GuardianErrors.CoolDownPeriodNotPassed.selector);
        lendingPoolGuardian.unpause();
        vm.stopPrank();
    }

    function testFuzz_Success_unPause(
        uint256 lastPauseTimestamp,
        uint256 timePassed,
        address sender,
        Flags memory initialFlags
    ) public {
        lastPauseTimestamp = bound(lastPauseTimestamp, 32 days + 1, type(uint32).max - 30 days - 1);
        timePassed = bound(timePassed, 30 days + 1, type(uint32).max);

        // Given: A random "lastPauseTimestamp".
        vm.warp(lastPauseTimestamp);
        vm.prank(users.guardian);
        lendingPoolGuardian.pause();

        // And: Flags are in random state.
        setFlags(initialFlags);

        // Given: More than 30 days passed.
        vm.warp(lastPauseTimestamp + timePassed);

        // When: A "sender" un-pauses.
        vm.startPrank(sender);
        vm.expectEmit(true, true, true, true);
        emit PauseFlagsUpdated(false, false, initialFlags.borrowPaused, initialFlags.depositPaused, false);
        lendingPoolGuardian.unpause();
        vm.stopPrank();

        // Then: All flags are set to False.
        assertFalse(lendingPoolGuardian.repayPaused());
        assertFalse(lendingPoolGuardian.withdrawPaused());
        assertEq(lendingPoolGuardian.borrowPaused(), initialFlags.borrowPaused);
        assertEq(lendingPoolGuardian.depositPaused(), initialFlags.depositPaused);
        assertFalse(lendingPoolGuardian.liquidationPaused());
    }
}
