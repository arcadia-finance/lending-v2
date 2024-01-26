/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "popTranche" of contract "LendingPool".
 */
contract PopTranche_LendingPool_Fuzz_Test is LendingPool_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LendingPool_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_popTranche() public {
        vm.prank(users.creatorAddress);
        pool.setInterestWeightTranche(0, 50);

        assertEq(pool.getTotalInterestWeight(), 100);
        assertEq(pool.getInterestWeightTranches(0), 50);
        assertEq(pool.getInterestWeightTranches(1), 40);
        assertTrue(pool.getIsTranche(address(srTranche)));
        assertTrue(pool.getIsTranche(address(jrTranche)));

        vm.expectEmit(true, true, true, true);
        emit TranchePopped(address(jrTranche));
        pool.popTranche(1, address(jrTranche));

        assertEq(pool.getTotalInterestWeight(), 60);
        assertEq(pool.getInterestWeightTranches(0), 50);
        assertEq(pool.getTranches(0), address(srTranche));
        assertTrue(pool.getIsTranche(address(srTranche)));
        assertFalse(pool.getIsTranche(address(jrTranche)));
    }
}
