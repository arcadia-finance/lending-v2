/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { InterestRateModule_Fuzz_Test } from "./_InterestRateModule.fuzz.t.sol";

import { InterestRateModule } from "../../../src/InterestRateModule.sol";

/**
 * @notice Fuzz tests for the "calculateInterestRate" of contract "InterestRateModule".
 */
contract CalculateInterestRate_InterestRateModule_Fuzz_Test is InterestRateModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        InterestRateModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testSuccess_calculateInterestRate_UnderOptimalUtilisation(
        uint40 utilisation,
        uint72 baseRate_,
        uint72 highSlope_,
        uint72 lowSlope_,
        uint40 utilisationThreshold_
    ) public {
        // Given: utilisation is between 0 and 80000, baseRate_ is less than 100000, highSlope_ is bigger than lowSlope_
        vm.assume(utilisationThreshold_ <= 100_000);
        vm.assume(utilisation <= utilisationThreshold_);

        // And: a certain InterestRateConfiguration
        InterestRateModule.InterestRateConfiguration memory config = InterestRateModule.InterestRateConfiguration({
            baseRatePerYear: baseRate_,
            highSlopePerYear: highSlope_,
            lowSlopePerYear: lowSlope_,
            utilisationThreshold: utilisationThreshold_
        });

        // When: The InterestConfiguration is set
        interestRateModule.setInterestConfig(config);

        // And: actualInterestRate is calculateInterestRate with utilisation
        uint256 actualInterestRate = interestRateModule.calculateInterestRate(utilisation);

        // And: expectedInterestRate is lowSlope multiplied by utilisation divided by 100000 and added to baseRate
        uint256 expectedInterestRate = uint256(baseRate_) + uint256(lowSlope_) * utilisation / 100_000;

        // Then: actualInterestRate should be equal to expectedInterestRate
        assertEq(actualInterestRate, expectedInterestRate);
    }

    function testSuccess_calculateInterestRate_OverOptimalUtilisation(
        uint40 utilisation,
        uint72 baseRate_,
        uint72 highSlope_,
        uint72 lowSlope_,
        uint40 utilisationThreshold_
    ) public {
        // Given: utilisation is between 80000 and 100000, highSlope_ is bigger than lowSlope_
        vm.assume(utilisationThreshold_ <= 100_000);
        vm.assume(utilisation > utilisationThreshold_);

        // And: a certain InterestRateConfiguration
        InterestRateModule.InterestRateConfiguration memory config = InterestRateModule.InterestRateConfiguration({
            baseRatePerYear: baseRate_,
            highSlopePerYear: highSlope_,
            lowSlopePerYear: lowSlope_,
            utilisationThreshold: utilisationThreshold_
        });

        // When: The InterestConfiguration is set
        interestRateModule.setInterestConfig(config);

        // And: lowSlopeInterest is utilisationThreshold multiplied by lowSlope, highSlopeInterest is utilisation minus utilisationThreshold multiplied by highSlope
        uint256 lowSlopeInterest = uint256(utilisationThreshold_) * lowSlope_;
        uint256 highSlopeInterest = uint256(utilisation - utilisationThreshold_) * highSlope_;

        // And: expectedInterestRate is baseRate added to lowSlopeInterest added to highSlopeInterest divided by divided by 100000
        uint256 expectedInterestRate = uint256(baseRate_) + (lowSlopeInterest + highSlopeInterest) / 100_000;

        // And: actualInterestRate is calculateInterestRate with utilisation
        uint256 actualInterestRate = interestRateModule.calculateInterestRate(utilisation);

        // Then: actualInterestRate should be equal to expectedInterestRate
        assertEq(actualInterestRate, expectedInterestRate);
    }
}
