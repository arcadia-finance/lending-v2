/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

import { LendingPool } from "../../../src/LendingPool.sol";

/**
 * @notice Fuzz tests for the function "setTreasuryWeights" of contract "LendingPool".
 */
contract SetTreasuryWeights_LendingPool_Fuzz_Test is LendingPool_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LendingPool_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_setTreasuryWeights_InvalidOwner(address unprivilegedAddress) public {
        vm.assume(unprivilegedAddress != users.owner);

        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
        pool.setTreasuryWeights(5, 10);
        vm.stopPrank();
    }

    function testFuzz_Success_setTreasuryWeights() public {
        vm.startPrank(users.owner);
        vm.expectEmit(true, true, true, true);
        emit LendingPool.TreasuryWeightsUpdated(5, 5);
        pool.setTreasuryWeights(5, 5);
        vm.stopPrank();

        assertEq(pool.getTotalInterestWeight(), 95);
        assertEq(pool.getInterestWeightTreasury(), 5);
        assertEq(pool.getLiquidationWeightTreasury(), 5);

        vm.startPrank(users.owner);
        pool.setTreasuryWeights(10, 10);
        vm.stopPrank();

        assertEq(pool.getTotalInterestWeight(), 100);
        assertEq(pool.getInterestWeightTreasury(), 10);
        assertEq(pool.getLiquidationWeightTreasury(), 10);
        assertEq(pool.getInterestWeight(pool.getTreasury()), 10);
    }
}
