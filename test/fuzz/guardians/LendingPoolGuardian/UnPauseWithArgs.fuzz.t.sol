/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { LendingPoolGuardian_Fuzz_Test } from "./_LendingPoolGuardian.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "unPause" of contract "LendingPoolGuardian".
 */
contract UnPause_WithArgs_LendingPoolGuardian_Fuzz_Test is LendingPoolGuardian_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LendingPoolGuardian_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_unPause_OnlyOwner(address nonOwner, Flags memory flags) public {
        vm.assume(nonOwner != users.creatorAddress);

        vm.startPrank(nonOwner);
        vm.expectRevert("UNAUTHORIZED");
        lendingPoolGuardian.unpause(
            flags.repayPaused, flags.withdrawPaused, flags.borrowPaused, flags.depositPaused, flags.liquidationPaused
        );
        vm.stopPrank();
    }

    function testFuzz_Success_unPause(
        uint256 lastPauseTimestamp,
        uint256 timePassed,
        Flags memory initialFlags,
        Flags memory flags
    ) public {
        lastPauseTimestamp = bound(lastPauseTimestamp, 32 days + 1, type(uint32).max);
        timePassed = bound(timePassed, 0, type(uint32).max);

        // Given: A random "lastPauseTimestamp".
        vm.warp(lastPauseTimestamp);
        vm.prank(users.guardian);
        lendingPoolGuardian.pause();

        // And: Flags are in random state.
        setFlags(initialFlags);

        // And: Some time passed.
        vm.warp(lastPauseTimestamp + timePassed);

        // When: A "owner" un-pauses.
        vm.startPrank(users.creatorAddress);
        vm.expectEmit(true, true, true, true);
        emit PauseFlagsUpdated(
            initialFlags.repayPaused && flags.repayPaused,
            initialFlags.withdrawPaused && flags.withdrawPaused,
            initialFlags.borrowPaused && flags.borrowPaused,
            initialFlags.depositPaused && flags.depositPaused,
            initialFlags.liquidationPaused && flags.liquidationPaused
        );
        lendingPoolGuardian.unpause(
            flags.repayPaused, flags.withdrawPaused, flags.borrowPaused, flags.depositPaused, flags.liquidationPaused
        );
        vm.stopPrank();

        // Then: Flags can only be toggled from paused (true) to unpaused (false)
        // if initialFlag was true en new flag is false.
        assertEq(lendingPoolGuardian.repayPaused(), initialFlags.repayPaused && flags.repayPaused);
        assertEq(lendingPoolGuardian.withdrawPaused(), initialFlags.withdrawPaused && flags.withdrawPaused);
        assertEq(lendingPoolGuardian.borrowPaused(), initialFlags.borrowPaused && flags.borrowPaused);
        assertEq(lendingPoolGuardian.depositPaused(), initialFlags.depositPaused && flags.depositPaused);
        assertEq(lendingPoolGuardian.liquidationPaused(), initialFlags.liquidationPaused && flags.liquidationPaused);
    }
}
