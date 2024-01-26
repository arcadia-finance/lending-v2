/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "updateInterestRate" of contract "LendingPool".
 */
contract UpdateInterestRate_LendingPool_Fuzz_Test is LendingPool_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LendingPool_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_updateInterestRate(
        address sender,
        uint24 deltaTimestamp,
        uint128 realisedDebt,
        uint120 realisedLiquidity,
        uint80 interestRate
    ) public {
        // realisedDebt smaller than equal to than 3402823669209384912995114146594816
        vm.assume(deltaTimestamp <= 5 * 365 * 24 * 60 * 60);
        //5 year
        vm.assume(interestRate <= 10 * 10 ** 18);
        //1000%
        vm.assume(realisedDebt <= type(uint128).max / (10 ** 5));
        //highest possible debt at 1000% over 5 years: 3402823669209384912995114146594816
        vm.assume(realisedDebt <= realisedLiquidity);

        pool.setTotalRealisedLiquidity(realisedLiquidity);
        pool.setRealisedDebt(realisedDebt);
        pool.setInterestRate(interestRate);
        pool.setLastSyncedTimestamp(uint32(block.timestamp));

        uint256 start_timestamp = block.timestamp;
        vm.warp(start_timestamp + deltaTimestamp);

        vm.prank(sender);
        pool.updateInterestRate();

        uint256 interest = calcUnrealisedDebtChecked(interestRate, deltaTimestamp, realisedDebt);

        assertEq(debt.totalAssets(), realisedDebt + interest);
        assertEq(pool.getLastSyncedTimestamp(), start_timestamp + deltaTimestamp);
        // Pools have no liquidity -> all interests go to the Treasury.
        assertEq(pool.liquidityOf(address(treasury)), interest);
        assertEq(pool.totalLiquidity(), realisedLiquidity + interest);
    }

    function testFuzz_Success_updateInterestRate_totalRealisedLiquidityMoreThanZero(
        uint128 realisedDebt_,
        uint128 totalRealisedLiquidity_,
        uint72 baseRate_,
        uint72 highSlope_,
        uint72 lowSlope_,
        uint16 utilisationThreshold_
    ) public {
        // Given: totalRealisedLiquidity_ is more than equal to 0, baseRate_ is less than 100000, highSlope_ is bigger than lowSlope_
        vm.assume(totalRealisedLiquidity_ > 0);
        vm.assume(realisedDebt_ <= type(uint128).max / ONE_4);
        vm.assume(realisedDebt_ <= totalRealisedLiquidity_);
        vm.assume(utilisationThreshold_ <= ONE_4);

        // When: The InterestConfiguration is set
        vm.prank(users.creatorAddress);
        pool.setInterestParameters(baseRate_, lowSlope_, highSlope_, utilisationThreshold_);

        // And: utilisation is 10_000 multiplied by realisedDebt_ and divided by totalRealisedLiquidity_
        uint256 utilisation = (ONE_4 * realisedDebt_) / totalRealisedLiquidity_;

        uint256 expectedInterestRate;

        if (utilisation <= utilisationThreshold_) {
            // And: expectedInterestRate is lowSlope multiplied by utilisation, divided by 10_000 and added to baseRate
            expectedInterestRate = uint256(baseRate_) + uint256(lowSlope_) * utilisation / ONE_4;
        } else {
            // And: lowSlopeInterest is utilisationThreshold multiplied by lowSlope,
            // highSlopeInterest is utilisation minus utilisationThreshold multiplied by highSlope
            uint256 lowSlopeInterest = uint256(utilisationThreshold_) * lowSlope_;
            uint256 highSlopeInterest = uint256(utilisation - utilisationThreshold_) * highSlope_;

            // And: expectedInterestRate is baseRate added to lowSlopeInterest added to highSlopeInterest divided by 10_000
            expectedInterestRate = uint256(baseRate_) + (lowSlopeInterest + highSlopeInterest) / ONE_4;
        }

        assertTrue(expectedInterestRate <= type(uint80).max);

        vm.expectEmit();
        emit PoolStateUpdated(uint256(realisedDebt_), uint256(totalRealisedLiquidity_), uint80(expectedInterestRate));
        pool.updateInterestRate(realisedDebt_, totalRealisedLiquidity_);
        uint256 actualInterestRate = pool.interestRate();

        // Then: actualInterestRate should be equal to expectedInterestRate
        assertEq(actualInterestRate, expectedInterestRate);
    }

    function testFuzz_Success_updateInterestRate_totalRealisedLiquidityZero(
        uint256 realisedDebt_,
        uint72 baseRate_,
        uint72 highSlope_,
        uint72 lowSlope_,
        uint16 utilisationThreshold_
    ) public {
        // Given: totalRealisedLiquidity_ is equal to 0, baseRate_ is less than 100000, highSlope_ is bigger than lowSlope_
        uint256 totalRealisedLiquidity_ = 0;
        vm.assume(realisedDebt_ <= type(uint128).max / ONE_4); //highest possible debt at 1000% over 5 years: 3402823669209384912995114146594816
        vm.assume(utilisationThreshold_ <= ONE_4);

        // When: The InterestConfiguration is set
        vm.prank(users.creatorAddress);
        pool.setInterestParameters(baseRate_, lowSlope_, highSlope_, utilisationThreshold_);
        // And: The interestRateModule is set for a certain combination of realisedDebt_ and totalRealisedLiquidity_
        pool.updateInterestRate(realisedDebt_, totalRealisedLiquidity_);

        uint256 expectedInterestRate = baseRate_;

        vm.expectEmit();
        emit PoolStateUpdated(uint256(realisedDebt_), uint256(totalRealisedLiquidity_), uint80(expectedInterestRate));
        pool.updateInterestRate(realisedDebt_, totalRealisedLiquidity_);
        uint256 actualInterestRate = pool.interestRate();

        // Then: actualInterestRate should be equal to expectedInterestRate
        assertEq(actualInterestRate, expectedInterestRate);
    }
}
