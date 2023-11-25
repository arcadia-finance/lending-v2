/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Tranche_Fuzz_Test } from "./_Tranche.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "unLock" of contract "Tranche".
 */
contract UnLock_Tranche_Fuzz_Test is Tranche_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Tranche_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_unlock_Unauthorised(address unprivilegedAddress) public {
        vm.assume(unprivilegedAddress != users.creatorAddress);

        vm.prank(address(pool));
        tranche.lock();
        assertTrue(tranche.locked());

        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
        tranche.unLock();
        vm.stopPrank();
    }

    function testFuzz_Success_unlock() public {
        vm.prank(address(pool));
        tranche.lock();
        assertTrue(tranche.locked());

        vm.startPrank(users.creatorAddress);
        vm.expectEmit(true, true, true, true);
        emit LockSet(false);
        tranche.unLock();
        vm.stopPrank();

        assertFalse(tranche.locked());
    }
}
