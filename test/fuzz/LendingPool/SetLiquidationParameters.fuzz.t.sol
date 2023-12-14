/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

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
        uint80 maxInitiationFee,
        uint80 maxTerminationFee
    ) public {
        vm.assume(unprivilegedAddress_ != users.creatorAddress);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("UNAUTHORIZED");
        pool.setLiquidationParameters(
            initiationWeight, penaltyWeight, terminationWeight, maxInitiationFee, maxTerminationFee
        );
        vm.stopPrank();
    }

    function testFuzz_Revert_setLiquidationParameters_AuctionsOngoing(
        uint16 auctionsInProgress,
        uint16 initiationWeight,
        uint16 penaltyWeight,
        uint16 terminationWeight,
        uint80 maxInitiationFee,
        uint80 maxTerminationFee
    ) public {
        auctionsInProgress = uint16(bound(auctionsInProgress, 1, type(uint16).max));
        pool.setAuctionsInProgress(auctionsInProgress);

        vm.startPrank(users.creatorAddress);
        vm.expectRevert(AuctionOngoing.selector);
        pool.setLiquidationParameters(
            initiationWeight, penaltyWeight, terminationWeight, maxInitiationFee, maxTerminationFee
        );
        vm.stopPrank();
    }

    function testFuzz_Revert_setLiquidationParameters_WeightsTooHigh(
        uint16 initiationWeight,
        uint16 penaltyWeight,
        uint16 terminationWeight,
        uint80 maxInitiationFee,
        uint80 maxTerminationFee
    ) public {
        vm.assume(uint32(initiationWeight) + penaltyWeight + terminationWeight > pool.getMaxTotalPenalty());

        vm.startPrank(users.creatorAddress);
        vm.expectRevert(LiquidationWeightsTooHigh.selector);
        pool.setLiquidationParameters(
            initiationWeight, penaltyWeight, terminationWeight, maxInitiationFee, maxTerminationFee
        );
        vm.stopPrank();
    }

    function testFuzz_Success_setLiquidationParameters(
        uint16 initiationWeight,
        uint16 penaltyWeight,
        uint16 terminationWeight,
        uint80 maxInitiationFee,
        uint80 maxTerminationFee
    ) public {
        vm.assume(uint32(initiationWeight) + penaltyWeight + terminationWeight <= pool.getMaxTotalPenalty());

        vm.startPrank(users.creatorAddress);
        vm.expectEmit();
        emit LiquidationParametersSet(
            initiationWeight, penaltyWeight, terminationWeight, maxInitiationFee, maxTerminationFee
        );
        pool.setLiquidationParameters(
            initiationWeight, penaltyWeight, terminationWeight, maxInitiationFee, maxTerminationFee
        );
        vm.stopPrank();

        assertEq(pool.getPenaltyWeight(), penaltyWeight);
        assertEq(pool.getInitiationRewardWeight(), initiationWeight);
        assertEq(pool.getTerminationRewardWeight(), terminationWeight);
        assertEq(pool.getMaxInitiationFee(), maxInitiationFee);
        assertEq(pool.getMaxTerminationFee(), maxTerminationFee);
    }
}
