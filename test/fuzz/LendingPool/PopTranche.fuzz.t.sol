/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

/**
 * @notice Fuzz tests for the "popTranche" of contract "LendingPool".
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
        pool.setLiquidationWeight(0, 10);

        assertEq(pool.totalInterestWeight(), 100);
        assertEq(pool.interestWeightTranches(0), 50);
        assertEq(pool.interestWeightTranches(1), 40);
        assertEq(pool.totalLiquidationWeight(), 110);
        assertEq(pool.liquidationWeightTranches(0), 10);
        assertEq(pool.liquidationWeightTranches(1), 20);
        assertTrue(pool.isTranche(address(srTranche)));
        assertTrue(pool.isTranche(address(jrTranche)));

        vm.expectEmit(true, true, true, true);
        emit TranchePopped(address(jrTranche));
        pool.popTranche(1, address(jrTranche));

        assertEq(pool.totalInterestWeight(), 60);
        assertEq(pool.interestWeightTranches(0), 50);
        assertEq(pool.totalLiquidationWeight(), 90);
        assertEq(pool.liquidationWeightTranches(0), 10);
        assertEq(pool.tranches(0), address(srTranche));
        assertTrue(pool.isTranche(address(srTranche)));
        assertTrue(!pool.isTranche(address(jrTranche)));
    }
}
