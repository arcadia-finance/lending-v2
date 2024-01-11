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
        LendingPool.LiquidationParameters memory params
    ) public {
        vm.assume(unprivilegedAddress_ != users.creatorAddress);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("UNAUTHORIZED");
        pool.setLiquidationParameters(params);
        vm.stopPrank();
    }

    function testFuzz_Revert_setLiquidationParameters_AuctionsOngoing(
        uint16 auctionsInProgress,
        LendingPool.LiquidationParameters memory params
    ) public {
        auctionsInProgress = uint16(bound(auctionsInProgress, 1, type(uint16).max));
        pool.setAuctionsInProgress(auctionsInProgress);

        vm.startPrank(users.creatorAddress);
        vm.expectRevert(AuctionOngoing.selector);
        pool.setLiquidationParameters(params);
        vm.stopPrank();
    }

    function testFuzz_Revert_setLiquidationParameters_WeightsTooHigh(LendingPool.LiquidationParameters memory params)
        public
    {
        vm.assume(
            uint32(params.initiationWeight) + params.penaltyWeight + params.terminationWeight
                > pool.getMaxTotalPenalty()
        );

        vm.startPrank(users.creatorAddress);
        vm.expectRevert(LiquidationWeightsTooHigh.selector);
        pool.setLiquidationParameters(params);
        vm.stopPrank();
    }

    function testFuzz_Revert_setLiquidationParameters_MinRewardWeightTooHigh(
        LendingPool.LiquidationParameters memory params
    ) public {
        vm.assume(
            uint32(params.initiationWeight) + params.penaltyWeight + params.terminationWeight
                <= pool.getMaxTotalPenalty()
        );

        params.minRewardWeight = uint16(bound(params.minRewardWeight, 5000 + 1, type(uint16).max));

        vm.startPrank(users.creatorAddress);
        vm.expectRevert(LiquidationWeightsTooHigh.selector);
        pool.setLiquidationParameters(params);
        vm.stopPrank();
    }

    function testFuzz_Success_setLiquidationParameters(LendingPool.LiquidationParameters memory params) public {
        vm.assume(
            uint32(params.initiationWeight) + params.penaltyWeight + params.terminationWeight
                <= pool.getMaxTotalPenalty()
        );

        params.minRewardWeight = uint16(bound(params.minRewardWeight, 0, 5000));

        vm.startPrank(users.creatorAddress);
        vm.expectEmit();
        emit LiquidationParametersSet(params);
        pool.setLiquidationParameters(params);
        vm.stopPrank();

        (
            uint80 maxInitiationReward,
            uint80 maxTerminationReward,
            uint16 minRewardWeight,
            uint16 initiationWeight,
            uint16 penaltyWeight,
            uint16 terminationWeight
        ) = pool.liquidationParameters();

        assertEq(penaltyWeight, params.penaltyWeight);
        assertEq(initiationWeight, params.initiationWeight);
        assertEq(terminationWeight, params.terminationWeight);
        assertEq(minRewardWeight, params.minRewardWeight);
        assertEq(maxInitiationReward, params.maxInitiationReward);
        assertEq(maxTerminationReward, params.maxTerminationReward);
    }
}
