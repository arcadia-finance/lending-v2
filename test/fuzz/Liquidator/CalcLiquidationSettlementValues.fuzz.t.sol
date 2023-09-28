/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Liquidator_Fuzz_Test } from "./_Liquidator.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "calcLiquidationSettlementValues" of contract "Liquidator".
 */
contract CalcLiquidationSettlementValues_Liquidator_Fuzz_Test is Liquidator_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Liquidator_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_calcLiquidationSettlementValues(
        uint128 openDebt,
        uint256 priceOfAccount,
        uint88 maxInitiatorFee
    ) public {
        uint8 penaltyWeight = liquidator.penaltyWeight();
        uint8 initiatorRewardWeight = liquidator.initiatorRewardWeight();
        uint256 expectedLiquidationInitiatorReward = uint256(openDebt) * initiatorRewardWeight / 100;
        expectedLiquidationInitiatorReward =
            expectedLiquidationInitiatorReward > maxInitiatorFee ? maxInitiatorFee : expectedLiquidationInitiatorReward;
        uint256 expectedBadDebt;
        uint256 expectedLiquidationPenalty;
        uint256 expectedRemainder;

        if (priceOfAccount < expectedLiquidationInitiatorReward + openDebt) {
            expectedBadDebt = expectedLiquidationInitiatorReward + openDebt - priceOfAccount;
        } else {
            expectedLiquidationPenalty = uint256(openDebt) * penaltyWeight / 100;
            expectedRemainder = priceOfAccount - openDebt - expectedLiquidationInitiatorReward;

            if (expectedRemainder > expectedLiquidationPenalty) {
                expectedRemainder -= expectedLiquidationPenalty;
            } else {
                expectedLiquidationPenalty = expectedRemainder;
                expectedRemainder = 0;
            }
        }

        (
            uint256 actualBadDebt,
            uint256 actualLiquidationInitiatorReward,
            uint256 actualLiquidationPenalty,
            uint256 actualRemainder
        ) = liquidator.calcLiquidationSettlementValues(
            openDebt, priceOfAccount, maxInitiatorFee, initiatorRewardWeight, penaltyWeight
        );

        assertEq(actualBadDebt, expectedBadDebt);
        assertEq(actualLiquidationInitiatorReward, expectedLiquidationInitiatorReward);
        assertEq(actualLiquidationPenalty, expectedLiquidationPenalty);
        assertEq(actualRemainder, expectedRemainder);
    }
}
