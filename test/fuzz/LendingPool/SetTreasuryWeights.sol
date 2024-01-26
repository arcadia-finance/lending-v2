/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

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
        vm.assume(unprivilegedAddress != users.creatorAddress);

        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
        pool.setTreasuryWeights(5, 10);
        vm.stopPrank();
    }

    function testFuzz_Success_setTreasuryWeights() public {
        vm.startPrank(users.creatorAddress);
        vm.expectEmit(true, true, true, true);
        emit TreasuryWeightsUpdated(5, 5);
        pool.setTreasuryWeights(5, 5);
        vm.stopPrank();

        assertEq(pool.getTotalInterestWeight(), 95);
        assertEq(pool.getInterestWeightTreasury(), 5);
        assertEq(pool.getLiquidationWeightTreasury(), 5);

        vm.startPrank(users.creatorAddress);
        pool.setTreasuryWeights(10, 10);
        vm.stopPrank();

        assertEq(pool.getTotalInterestWeight(), 100);
        assertEq(pool.getInterestWeightTreasury(), 10);
        assertEq(pool.getLiquidationWeightTreasury(), 10);
    }
}
