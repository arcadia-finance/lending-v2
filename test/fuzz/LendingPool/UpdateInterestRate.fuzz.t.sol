/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

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
        uint256 interestRate
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
        pool.setLastSyncedTimestamp(uint32(block.number));

        uint256 start_timestamp = block.timestamp;
        vm.warp(start_timestamp + deltaTimestamp);

        vm.prank(sender);
        pool.updateInterestRate();

        uint256 interest = calcUnrealisedDebtChecked(interestRate, deltaTimestamp, realisedDebt);
        uint256 interestSr = interest * 50 / 100;
        uint256 interestJr = interest * 40 / 100;
        uint256 interestTreasury = interest - interestSr - interestJr;

        assertEq(debt.totalAssets(), realisedDebt + interest);
        assertEq(pool.getLastSyncedTimestamp(), start_timestamp + deltaTimestamp);
        assertEq(pool.realisedLiquidityOf(address(srTranche)), interestSr);
        assertEq(pool.realisedLiquidityOf(address(jrTranche)), interestJr);
        assertEq(pool.realisedLiquidityOf(address(treasury)), interestTreasury);
        assertEq(pool.totalRealisedLiquidity(), realisedLiquidity + interest);
    }
}
