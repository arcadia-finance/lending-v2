/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { LiquidatorL2_Fuzz_Test } from "./_LiquidatorL2.fuzz.t.sol";

import { LiquidatorErrors } from "../../../../src/libraries/Errors.sol";

/**
 * @notice Fuzz tests for the function "_getSequencerUpTime" of contract "LiquidatorL2".
 */
contract GetSequencerUpTime_LiquidatorL2_Fuzz_Test is LiquidatorL2_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LiquidatorL2_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_getSequencerUpTime_SequencerDown(uint32 startedAt) public {
        // Given: a random startedAt time.
        // And: Sequencer is down.
        sequencerUptimeOracle.setLatestRoundData(1, startedAt);

        // When: "_getSequencerUpTime()" is called.
        // Then: tx reverts.
        vm.expectRevert(LiquidatorErrors.SequencerDown.selector);
        liquidator.getSequencerUpTime();
    }

    function testFuzz_Success_getSequencerUpTime_SequencerUp(uint32 startedAt) public {
        // Given: sequencer is back online.
        sequencerUptimeOracle.setLatestRoundData(0, startedAt);

        // When: "_getSequencerUpTime()" is called.
        (bool success, uint256 startedAt_) = liquidator.getSequencerUpTime();

        // Then: Correct variables are returned.
        assertTrue(success);
        assertEq(startedAt_, startedAt);
    }

    function testFuzz_Success_getSequencerUpTime_RevertingOracle(uint32 startedAt, int256 answer) public {
        // Given: Random latestRoundData.
        sequencerUptimeOracle.setLatestRoundData(answer, startedAt);

        // And: sequencer oracle will revert.
        sequencerUptimeOracle.setRevertsFlag(true);

        // When: "_getSequencerUpTime()" is called.
        (bool success, uint256 startedAt_) = liquidator.getSequencerUpTime();

        // Then: Correct variables are returned.
        assertFalse(success);
        assertEq(startedAt_, 0);
    }

    function testFuzz_Success_getSequencerUpTime_RandomAnswer(uint32 startedAt, int256 answer) public {
        // Given: answer is not 1.
        vm.assume(answer != 1);

        // Given: sequencer is back online.
        sequencerUptimeOracle.setLatestRoundData(answer, startedAt);

        // When: "_getSequencerUpTime()" is called.
        (bool success, uint256 startedAt_) = liquidator.getSequencerUpTime();

        // Then: Correct variables are returned.
        assertTrue(success);
        assertEq(startedAt_, startedAt);
    }
}
