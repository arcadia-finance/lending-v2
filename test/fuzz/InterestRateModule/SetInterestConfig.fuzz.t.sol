/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { InterestRateModule_Fuzz_Test } from "./_InterestRateModule.fuzz.t.sol";

import { InterestRateModule } from "../../../src/InterestRateModule.sol";

/**
 * @notice Fuzz tests for the "setInterestConfig" of contract "InterestRateModule".
 */
contract SetInterestConfig_InterestRateModule_Fuzz_Test is InterestRateModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        InterestRateModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testSuccess_setInterestConfig(
        uint72 baseRate_,
        uint72 highSlope_,
        uint72 lowSlope_,
        uint8 utilisationThreshold_
    ) public {
        // Given: A certain InterestRateConfiguration
        InterestRateModule.InterestRateConfiguration memory config = InterestRateModule.InterestRateConfiguration({
            baseRatePerYear: baseRate_,
            highSlopePerYear: highSlope_,
            lowSlopePerYear: lowSlope_,
            utilisationThreshold: utilisationThreshold_
        });
        // When: The InterestConfiguration is set
        interestRateModule.setInterestConfig(config);

        // Then: config types should be equal to fuzzed types
        (uint256 baseRatePerYear, uint256 lowSlopePerYear, uint256 highSlopePerYear, uint256 utilisationThreshold) =
            interestRateModule.interestRateConfig();
        assertEq(baseRatePerYear, baseRate_);
        assertEq(highSlopePerYear, highSlope_);
        assertEq(lowSlopePerYear, lowSlope_);
        assertEq(utilisationThreshold, utilisationThreshold_);
    }
}
