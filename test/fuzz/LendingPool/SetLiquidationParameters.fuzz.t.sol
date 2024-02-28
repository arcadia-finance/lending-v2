/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

import { LendingPool } from "../../../src/LendingPool.sol";

/**
 * @notice Fuzz tests for the function "setLiquidationParameters" of contract "LendingPool".
 */
contract SetLiquidationParameters_LendingPool_Fuzz_Test is LendingPool_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LendingPool_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_setLiquidationParameters_NonOwner(
        address unprivilegedAddress_,
        uint16 initiationWeight,
        uint16 penaltyWeight,
        uint16 terminationWeight,
        uint16 minRewardWeight,
        uint80 maxReward
    ) public {
        vm.assume(unprivilegedAddress_ != users.creatorAddress);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("UNAUTHORIZED");
        pool.setLiquidationParameters(initiationWeight, penaltyWeight, terminationWeight, minRewardWeight, maxReward);
        vm.stopPrank();
    }

    function testFuzz_Revert_setLiquidationParameters_AuctionsOngoing(
        uint16 auctionsInProgress,
        uint16 initiationWeight,
        uint16 penaltyWeight,
        uint16 terminationWeight,
        uint16 minRewardWeight,
        uint80 maxReward
    ) public {
        auctionsInProgress = uint16(bound(auctionsInProgress, 1, type(uint16).max));
        pool.setAuctionsInProgress(auctionsInProgress);

        vm.startPrank(users.creatorAddress);
        vm.expectRevert(AuctionOngoing.selector);
        pool.setLiquidationParameters(initiationWeight, penaltyWeight, terminationWeight, minRewardWeight, maxReward);
        vm.stopPrank();
    }

    function testFuzz_Revert_setLiquidationParameters_WeightsTooHigh(
        uint16 initiationWeight,
        uint16 penaltyWeight,
        uint16 terminationWeight,
        uint16 minRewardWeight,
        uint80 maxReward
    ) public {
        vm.assume(uint32(initiationWeight) + penaltyWeight + terminationWeight > pool.getMaxTotalPenalty());

        vm.startPrank(users.creatorAddress);
        vm.expectRevert(LiquidationWeightsTooHigh.selector);
        pool.setLiquidationParameters(initiationWeight, penaltyWeight, terminationWeight, minRewardWeight, maxReward);
        vm.stopPrank();
    }

    function testFuzz_Revert_setLiquidationParameters_MinRewardWeightTooHigh(
        uint16 initiationWeight,
        uint16 penaltyWeight,
        uint16 terminationWeight,
        uint16 minRewardWeight,
        uint80 maxReward
    ) public {
        vm.assume(uint32(initiationWeight) + penaltyWeight + terminationWeight <= pool.getMaxTotalPenalty());

        minRewardWeight = uint16(bound(minRewardWeight, 5000 + 1, type(uint16).max));

        vm.startPrank(users.creatorAddress);
        vm.expectRevert(LiquidationWeightsTooHigh.selector);
        pool.setLiquidationParameters(initiationWeight, penaltyWeight, terminationWeight, minRewardWeight, maxReward);
        vm.stopPrank();
    }

    function testFuzz_Success_setLiquidationParameters(
        uint16 initiationWeight,
        uint16 penaltyWeight,
        uint16 terminationWeight,
        uint16 minRewardWeight,
        uint80 maxReward
    ) public {
        vm.assume(uint32(initiationWeight) + penaltyWeight + terminationWeight <= pool.getMaxTotalPenalty());

        minRewardWeight = uint16(bound(minRewardWeight, 0, 5000));

        vm.prank(users.creatorAddress);
        pool.setLiquidationParameters(initiationWeight, penaltyWeight, terminationWeight, minRewardWeight, maxReward);

        (
            uint16 initiationWeight_,
            uint16 penaltyWeight_,
            uint16 terminationWeight_,
            uint16 minRewardWeight_,
            uint80 maxReward_
        ) = pool.getLiquidationParameters();

        assertEq(penaltyWeight_, penaltyWeight);
        assertEq(initiationWeight_, initiationWeight);
        assertEq(terminationWeight_, terminationWeight);
        assertEq(minRewardWeight_, minRewardWeight);
        assertEq(maxReward_, maxReward);
    }
}
