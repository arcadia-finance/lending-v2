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
        uint16 initiatorRewardWeight,
        uint16 penaltyWeight,
        uint16 closingRewardWeight
    ) public {
        vm.assume(unprivilegedAddress_ != users.creatorAddress);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("UNAUTHORIZED");
        pool.setWeights(initiatorRewardWeight, penaltyWeight, closingRewardWeight);
        vm.stopPrank();
    }

    function testFuzz_Revert_setWeights_WeightsTooHigh(
        uint16 initiatorRewardWeight,
        uint16 penaltyWeight,
        uint16 closingRewardWeight
    ) public {
        vm.assume(uint32(initiatorRewardWeight) + penaltyWeight + closingRewardWeight > 1100);

        vm.startPrank(users.creatorAddress);
        vm.expectRevert(LendingPool_WeightsTooHigh.selector);
        pool.setWeights(initiatorRewardWeight, penaltyWeight, closingRewardWeight);
        vm.stopPrank();
    }

    function testFuzz_Success_setWeights(uint16 initiatorRewardWeight, uint16 penaltyWeight, uint16 closingRewardWeight)
        public
    {
        vm.assume(uint32(initiatorRewardWeight) + penaltyWeight + closingRewardWeight <= 1100);

        vm.startPrank(users.creatorAddress);
        vm.expectEmit();
        emit WeightsSet(initiatorRewardWeight, penaltyWeight, closingRewardWeight);
        pool.setWeights(initiatorRewardWeight, penaltyWeight, closingRewardWeight);
        vm.stopPrank();

        assertEq(pool.getPenaltyWeight(), penaltyWeight);
        assertEq(pool.getInitiatorRewardWeight(), initiatorRewardWeight);
        assertEq(pool.getClosingRewardWeight(), closingRewardWeight);
    }
}
