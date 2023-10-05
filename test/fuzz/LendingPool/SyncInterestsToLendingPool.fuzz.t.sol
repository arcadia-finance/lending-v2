/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

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
        pool.setInterestWeight(0, weightSr);
        pool.setInterestWeight(1, weightJr);
        pool.setTreasuryInterestWeight(weightTreasury);
        vm.stopPrank();

        pool.syncInterestsToLendingPool(interests);

        uint256 interestSr = uint256(interests) * weightSr / totalInterestWeight;
        uint256 interestJr = uint256(interests) * weightJr / totalInterestWeight;
        uint256 interestTreasury = interests - interestSr - interestJr;

        assertEq(pool.getRealisedLiquidityOf(address(srTranche)), interestSr);
        assertEq(pool.getRealisedLiquidityOf(address(jrTranche)), interestJr);
        assertEq(pool.getRealisedLiquidityOf(address(treasury)), interestTreasury);
        assertEq(pool.totalRealisedLiquidity(), interests);
    }
}
