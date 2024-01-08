/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "calcUnrealisedDebt" of contract "LendingPool".
 */
contract CalcUnrealisedDebt_LendingPool_Fuzz_Test is LendingPool_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LendingPool_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_calcUnrealisedDebt(uint24 deltaTimestamp, uint128 realisedDebt, uint80 interestRate)
        public
    {
        // Given: deltaTimestamp smaller than equal to 5 years,
        // realisedDebt smaller than equal to than 3402823669209384912995114146594816
        vm.assume(deltaTimestamp <= 5 * 365 * 24 * 60 * 60);
        //5 year
        vm.assume(interestRate <= 10 * 10 ** 18);
        //1000%
        vm.assume(realisedDebt <= type(uint128).max / (10 ** 5));
        //highest possible debt at 1000% over 5 years: 3402823669209384912995114146594816

        pool.setInterestRate(interestRate);
        pool.setLastSyncedTimestamp(uint32(block.timestamp));
        pool.setRealisedDebt(realisedDebt);

        vm.warp(block.timestamp + deltaTimestamp);

        // Then: Unrealised debt should never overflow.
        // -> calcUnrealisedDebtChecked does never error and same calculations unchecked are always equal.
        uint256 expectedValue = calcUnrealisedDebtChecked(interestRate, deltaTimestamp, realisedDebt);
        uint256 actualValue = pool.calcUnrealisedDebt();
        assertEq(expectedValue, actualValue);
    }
}
