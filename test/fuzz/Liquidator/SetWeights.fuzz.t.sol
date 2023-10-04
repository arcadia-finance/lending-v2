/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Liquidator_Fuzz_Test } from "./_Liquidator.fuzz.t.sol";

import { Errors } from "../../../src/libraries/Errors.sol";
/**
 * @notice Fuzz tests for the function "setWeights" of contract "Liquidator".
 */

contract SetWeights_Liquidator_Fuzz_Test is Liquidator_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Liquidator_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_setWeights_NonOwner(
        address unprivilegedAddress_,
        uint8 initiatorRewardWeight,
        uint8 penaltyWeight
    ) public {
        vm.assume(unprivilegedAddress_ != users.creatorAddress);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("UNAUTHORIZED");
        liquidator.setWeights(initiatorRewardWeight, penaltyWeight);
        vm.stopPrank();
    }

    function testFuzz_Revert_setWeights_WeightsTooHigh(uint8 initiatorRewardWeight, uint8 penaltyWeight) public {
        vm.assume(uint16(initiatorRewardWeight) + penaltyWeight > 11);

        vm.startPrank(users.creatorAddress);
        vm.expectRevert(Errors.Liquidator_WeightsTooHigh.selector);
        liquidator.setWeights(initiatorRewardWeight, penaltyWeight);
        vm.stopPrank();
    }

    function testFuzz_Success_setWeights(uint8 initiatorRewardWeight, uint8 penaltyWeight) public {
        vm.assume(uint16(initiatorRewardWeight) + penaltyWeight <= 11);

        vm.startPrank(users.creatorAddress);
        vm.expectEmit(true, true, true, true);
        emit WeightsSet(initiatorRewardWeight, penaltyWeight);
        liquidator.setWeights(initiatorRewardWeight, penaltyWeight);
        vm.stopPrank();

        assertEq(liquidator.penaltyWeight(), penaltyWeight);
        assertEq(liquidator.initiatorRewardWeight(), initiatorRewardWeight);
    }
}
