/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { InterestRateModule_Fuzz_Test } from "./_InterestRateModule.fuzz.t.sol";

import { InterestRateModule } from "../../../src/InterestRateModule.sol";

/**
 * @notice Fuzz tests for the "updateInterestRate" of contract "InterestRateModule".
 */
contract UpdateInterestRate_InterestRateModule_Fuzz_Test is InterestRateModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        InterestRateModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_updateInterestRate_totalRealisedLiquidityMoreThanZero(
        uint128 realisedDebt_,
        uint128 totalRealisedLiquidity_,
        uint72 baseRate_,
        uint72 highSlope_,
        uint72 lowSlope_,
        uint40 utilisationThreshold_
    ) public {
        // Given: totalRealisedLiquidity_ is more than equal to 0, baseRate_ is less than 100000, highSlope_ is bigger than lowSlope_
        vm.assume(totalRealisedLiquidity_ > 0);
        vm.assume(realisedDebt_ <= type(uint128).max / (10 ** 5));
        vm.assume(realisedDebt_ <= totalRealisedLiquidity_);
        vm.assume(utilisationThreshold_ <= 100_000);

        InterestRateModule.InterestRateConfiguration memory config = InterestRateModule.InterestRateConfiguration({
            baseRatePerYear: baseRate_,
            highSlopePerYear: highSlope_,
            lowSlopePerYear: lowSlope_,
            utilisationThreshold: utilisationThreshold_
        });

        // When: The InterestConfiguration is set
        interestRateModule.setInterestConfig(config);

        // And: utilisation is 100_000 multiplied by realisedDebt_ and divided by totalRealisedLiquidity_
        uint256 utilisation = (100_000 * realisedDebt_) / totalRealisedLiquidity_;

        uint256 expectedInterestRate;

        if (utilisation <= utilisationThreshold_) {
            // And: expectedInterestRate is lowSlope multiplied by utilisation, divided by 100000 and added to baseRate
            expectedInterestRate = uint256(baseRate_) + uint256(lowSlope_) * utilisation / 100_000;
        } else {
            // And: lowSlopeInterest is utilisationThreshold multiplied by lowSlope,
            // highSlopeInterest is utilisation minus utilisationThreshold multiplied by highSlope
            uint256 lowSlopeInterest = uint256(utilisationThreshold_) * lowSlope_;
            uint256 highSlopeInterest = uint256(utilisation - config.utilisationThreshold) * highSlope_;

            // And: expectedInterestRate is baseRate added to lowSlopeInterest added to highSlopeInterest divided by 100000
            expectedInterestRate = uint256(baseRate_) + (lowSlopeInterest + highSlopeInterest) / 100_000;
        }

        assertTrue(expectedInterestRate <= type(uint80).max);

        vm.expectEmit(true, true, true, true);
        emit InterestRate(uint80(expectedInterestRate));
        interestRateModule.updateInterestRate(realisedDebt_, totalRealisedLiquidity_);
        uint256 actualInterestRate = interestRateModule.interestRate();

        // Then: actualInterestRate should be equal to expectedInterestRate
        assertEq(actualInterestRate, expectedInterestRate);
    }

    function testFuzz_Success_updateInterestRate_totalRealisedLiquidityZero(
        uint256 realisedDebt_,
        uint72 baseRate_,
        uint72 highSlope_,
        uint72 lowSlope_,
        uint40 utilisationThreshold_
    ) public {
        // Given: totalRealisedLiquidity_ is equal to 0, baseRate_ is less than 100000, highSlope_ is bigger than lowSlope_
        uint256 totalRealisedLiquidity_ = 0;
        vm.assume(realisedDebt_ <= type(uint128).max / (10 ** 5)); //highest possible debt at 1000% over 5 years: 3402823669209384912995114146594816
        vm.assume(utilisationThreshold_ <= 100_000);

        // And: a certain InterestRateConfiguration
        InterestRateModule.InterestRateConfiguration memory config = InterestRateModule.InterestRateConfiguration({
            baseRatePerYear: baseRate_,
            highSlopePerYear: highSlope_,
            lowSlopePerYear: lowSlope_,
            utilisationThreshold: utilisationThreshold_
        });

        // When: The InterestConfiguration is set
        interestRateModule.setInterestConfig(config);
        // And: The interestRateModule is set for a certain combination of realisedDebt_ and totalRealisedLiquidity_
        interestRateModule.updateInterestRate(realisedDebt_, totalRealisedLiquidity_);

        uint256 expectedInterestRate = baseRate_;

        vm.expectEmit(true, true, true, true);
        emit InterestRate(uint80(expectedInterestRate));
        interestRateModule.updateInterestRate(realisedDebt_, totalRealisedLiquidity_);
        uint256 actualInterestRate = interestRateModule.interestRate();

        // Then: actualInterestRate should be equal to expectedInterestRate
        assertEq(actualInterestRate, expectedInterestRate);
    }
}
