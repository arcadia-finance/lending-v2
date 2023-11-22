/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "setWeights" of contract "LendingPool".
 */
contract SetWeights_LendingPool_Fuzz_Test is LendingPool_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LendingPool_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_setWeights_NonOwner(
        address unprivilegedAddress_,
        uint16 initiationWeight,
        uint16 penaltyWeight,
        uint16 terminationWeight
    ) public {
        vm.assume(unprivilegedAddress_ != users.creatorAddress);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("UNAUTHORIZED");
        pool.setWeights(initiationWeight, penaltyWeight, terminationWeight);
        vm.stopPrank();
    }

    function testFuzz_Revert_setWeights_WeightsTooHigh(
        uint16 initiationWeight,
        uint16 penaltyWeight,
        uint16 terminationWeight
    ) public {
        vm.assume(uint32(initiationWeight) + penaltyWeight + terminationWeight > 1100);

        vm.startPrank(users.creatorAddress);
        vm.expectRevert(WeightsTooHigh.selector);
        pool.setWeights(initiationWeight, penaltyWeight, terminationWeight);
        vm.stopPrank();
    }

    function testFuzz_Success_setWeights(uint16 initiationWeight, uint16 penaltyWeight, uint16 terminationWeight)
        public
    {
        vm.assume(uint32(initiationWeight) + penaltyWeight + terminationWeight <= 1100);

        vm.startPrank(users.creatorAddress);
        vm.expectEmit();
        emit LiquidationWeightsSet(initiationWeight, penaltyWeight, terminationWeight);
        pool.setWeights(initiationWeight, penaltyWeight, terminationWeight);
        vm.stopPrank();

        assertEq(pool.getPenaltyWeight(), penaltyWeight);
        assertEq(pool.getInitiatorRewardWeight(), initiationWeight);
        assertEq(pool.getClosingRewardWeight(), terminationWeight);
    }
}
