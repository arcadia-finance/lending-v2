/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "setTreasuryLiquidationWeight" of contract "LendingPool".
 */

contract SetTreasuryLiquidationWeight_LendingPool_Fuzz_Test is LendingPool_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LendingPool_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_setTreasuryLiquidationWeight_InvalidOwner(address unprivilegedAddress) public {
        vm.assume(unprivilegedAddress != users.creatorAddress);

        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
        pool.setTreasuryLiquidationWeight(5);
        vm.stopPrank();
    }

    function testFuzz_Success_setTreasuryLiquidationWeight() public {
        vm.startPrank(users.creatorAddress);
        vm.expectEmit(true, true, true, true);
        emit TreasuryLiquidationWeightSet(5);
        pool.setTreasuryLiquidationWeight(5);
        vm.stopPrank();

        assertEq(pool.getTotalLiquidationWeight(), 25);
        assertEq(pool.getLiquidationWeightTreasury(), 5);

        vm.prank(users.creatorAddress);
        pool.setTreasuryLiquidationWeight(10);

        assertEq(pool.getTotalLiquidationWeight(), 30);
        assertEq(pool.getLiquidationWeightTreasury(), 10);
    }
}
