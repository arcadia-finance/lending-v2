/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "syncInterestsToLendingPool" of contract "LendingPool".
 */
contract SyncInterestsToLendingPool_LendingPool_Fuzz_Test is LendingPool_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LendingPool_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_syncInterestsToLiquidityProviders(
        uint128 interests,
        uint8 weightSr,
        uint8 weightJr,
        uint8 weightTreasury
    ) public {
        uint256 totalInterestWeight = uint256(weightSr) + uint256(weightJr) + uint256(weightTreasury);
        vm.assume(totalInterestWeight > 0);

        vm.startPrank(users.creatorAddress);
        pool.setTrancheWeights(0, weightSr, 0);
        pool.setTrancheWeights(1, weightJr, 10);
        pool.setTreasuryWeights(weightTreasury, 10);
        vm.stopPrank();

        pool.syncInterestsToLendingPool(interests);

        uint256 interestSr = uint256(interests) * weightSr / totalInterestWeight;
        uint256 interestJr = uint256(interests) * weightJr / totalInterestWeight;
        uint256 interestTreasury = interests - interestSr - interestJr;

        assertEq(pool.realisedLiquidityOf(address(srTranche)), interestSr);
        assertEq(pool.realisedLiquidityOf(address(jrTranche)), interestJr);
        assertEq(pool.realisedLiquidityOf(address(treasury)), interestTreasury);
        assertEq(pool.totalRealisedLiquidity(), interests);
    }
}
