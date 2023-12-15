/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

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
    function testFuzz_Success_calculateInterestRate_RepayPaused(
        uint40 utilisation,
        uint72 baseRate_,
        uint72 highSlope_,
        uint72 lowSlope_,
        uint16 utilisationThreshold_
    ) public {
        // Given: utilisation is less than 10_000.
        utilisationThreshold_ = uint16(bound(utilisationThreshold_, 0, ONE_4));

        // And: The InterestConfiguration is set.
        vm.prank(users.creatorAddress);
        pool.setInterestParameters(baseRate_, lowSlope_, highSlope_, utilisationThreshold_);

        // And: Repay is paused.
        vm.warp(35 days);
        vm.prank(users.guardian);
        pool.pause();

        // When: Interest is calculated.
        uint256 interestRate = pool.calculateInterestRate(utilisation);

        // Then: Interest should be be 0.
        assertEq(interestRate, 0);
    }

    function testFuzz_Success_calculateInterestRate_UnderOptimalUtilisation(
        uint40 utilisation,
        uint72 baseRate_,
        uint72 highSlope_,
        uint72 lowSlope_,
        uint16 utilisationThreshold_
    ) public {
        // Given: utilisation is less than 10_000.
        utilisationThreshold_ = uint16(bound(utilisationThreshold_, 0, ONE_4));

        // And: utilisation is below utilisationThreshold_.
        utilisation = uint40(bound(utilisation, 0, utilisationThreshold_));

        // When: The InterestConfiguration is set
        vm.prank(users.creatorAddress);
        pool.setInterestParameters(baseRate_, lowSlope_, highSlope_, utilisationThreshold_);

        // When: Interest is calculated.
        uint256 actualInterestRate = pool.calculateInterestRate(utilisation);

        // Then: actualInterestRate should be equal to expectedInterestRate
        uint256 expectedInterestRate = uint256(baseRate_) + uint256(lowSlope_) * utilisation / ONE_4;
        assertEq(actualInterestRate, expectedInterestRate);
    }

    function testFuzz_Success_calculateInterestRate_OverOptimalUtilisation(
        uint40 utilisation,
        uint72 baseRate_,
        uint72 highSlope_,
        uint72 lowSlope_,
        uint16 utilisationThreshold_
    ) public {
        // Given: utilisation is less than 10_000.
        utilisationThreshold_ = uint16(bound(utilisationThreshold_, 0, ONE_4));

        // And: utilisation is above utilisationThreshold_.
        utilisation = uint40(bound(utilisation, utilisationThreshold_ + 1, ONE_4));

        // And: The InterestConfiguration is set.
        vm.prank(users.creatorAddress);
        pool.setInterestParameters(baseRate_, lowSlope_, highSlope_, utilisationThreshold_);

        // And: lowSlopeInterest is utilisationThreshold multiplied by lowSlope, highSlopeInterest is utilisation minus utilisationThreshold multiplied by highSlope
        uint256 lowSlopeInterest = uint256(utilisationThreshold_) * lowSlope_;
        uint256 highSlopeInterest = uint256(utilisation - utilisationThreshold_) * highSlope_;

        // When: Interest is calculated.
        uint256 actualInterestRate = pool.calculateInterestRate(utilisation);

        // Then: actualInterestRate should be equal to expectedInterestRate
        uint256 expectedInterestRate = uint256(baseRate_) + (lowSlopeInterest + highSlopeInterest) / ONE_4;
        assertEq(actualInterestRate, expectedInterestRate);
    }
}
