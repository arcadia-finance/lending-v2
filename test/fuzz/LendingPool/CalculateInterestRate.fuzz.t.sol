/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "calculateInterestRate" of contract "InterestRateModule".
 */
contract CalculateInterestRate_LendingPool_Fuzz_Test is LendingPool_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LendingPool_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_calculateInterestRate_UnderOptimalUtilisation(
        uint40 utilisation,
        uint72 baseRate_,
        uint72 highSlope_,
        uint72 lowSlope_,
        uint16 utilisationThreshold_
    ) public {
        // Given: utilisation is between 0 and 80000, baseRate_ is less than 10_000, highSlope_ is bigger than lowSlope_
        vm.assume(utilisationThreshold_ <= ONE_4);
        vm.assume(utilisation <= utilisationThreshold_);

        // When: The InterestConfiguration is set
        vm.prank(users.creatorAddress);
        pool.setInterestParameters(baseRate_, lowSlope_, highSlope_, utilisationThreshold_);

        // And: actualInterestRate is calculateInterestRate with utilisation
        uint256 actualInterestRate = pool.calculateInterestRate(utilisation);

        // And: expectedInterestRate is lowSlope multiplied by utilisation divided by 10_000 and added to baseRate
        uint256 expectedInterestRate = uint256(baseRate_) + uint256(lowSlope_) * utilisation / ONE_4;

        // Then: actualInterestRate should be equal to expectedInterestRate
        assertEq(actualInterestRate, expectedInterestRate);
    }

    function testFuzz_Success_calculateInterestRate_OverOptimalUtilisation(
        uint40 utilisation,
        uint72 baseRate_,
        uint72 highSlope_,
        uint72 lowSlope_,
        uint16 utilisationThreshold_
    ) public {
        // Given: utilisation is between 80000 and 100000, highSlope_ is bigger than lowSlope_
        vm.assume(utilisationThreshold_ <= ONE_4);
        vm.assume(utilisation > utilisationThreshold_);

        // When: The InterestConfiguration is set
        vm.prank(users.creatorAddress);
        pool.setInterestParameters(baseRate_, lowSlope_, highSlope_, utilisationThreshold_);

        // And: lowSlopeInterest is utilisationThreshold multiplied by lowSlope, highSlopeInterest is utilisation minus utilisationThreshold multiplied by highSlope
        uint256 lowSlopeInterest = uint256(utilisationThreshold_) * lowSlope_;
        uint256 highSlopeInterest = uint256(utilisation - utilisationThreshold_) * highSlope_;

        // And: expectedInterestRate is baseRate added to lowSlopeInterest added to highSlopeInterest divided by divided by 10_000
        uint256 expectedInterestRate = uint256(baseRate_) + (lowSlopeInterest + highSlopeInterest) / ONE_4;

        // And: actualInterestRate is calculateInterestRate with utilisation
        uint256 actualInterestRate = pool.calculateInterestRate(utilisation);

        // Then: actualInterestRate should be equal to expectedInterestRate
        assertEq(actualInterestRate, expectedInterestRate);
    }
}
