/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

import { stdStorage, StdStorage } from "../../../lib/accounts-v2/lib/forge-std/src/StdStorage.sol";

/**
 * @notice Fuzz tests for the function "syncInterestsToLendingPool" of contract "LendingPool".
 */
contract SyncInterestsToLendingPool_LendingPool_Fuzz_Test is LendingPool_Fuzz_Test {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LendingPool_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_syncInterestsToLiquidityProviders_ZeroLiquidity(
        uint128 interests,
        uint8 weightSr,
        uint8 weightJr,
        uint8 weightTreasury
    ) public {
        uint256 totalInterestWeight = uint256(weightSr) + uint256(weightJr) + uint256(weightTreasury);
        vm.assume(totalInterestWeight > 0);

        vm.startPrank(users.creatorAddress);
        pool.setInterestWeightTranche(0, weightSr);
        pool.setInterestWeightTranche(1, weightJr);
        pool.setTreasuryWeights(weightTreasury, 10);
        vm.stopPrank();

        pool.syncInterestsToLendingPool(interests);

        assertEq(pool.realisedLiquidityOf(address(srTranche)), 0);
        assertEq(pool.realisedLiquidityOf(address(jrTranche)), 0);
        assertEq(pool.realisedLiquidityOf(address(treasury)), interests);
        // We did not set initial totalRealisedLiquidity.
        assertEq(pool.totalRealisedLiquidity(), interests);
    }

    function testFuzz_Success_syncInterestsToLiquidityProviders_NonZeroLiquidity(
        uint128 interests,
        uint8 weightSr,
        uint8 weightJr,
        uint8 weightTreasury,
        uint128 liquiditySr,
        uint128 liquidityJr
    ) public {
        uint256 totalInterestWeight = uint256(weightSr) + uint256(weightJr) + uint256(weightTreasury);
        vm.assume(totalInterestWeight > 0);

        vm.startPrank(users.creatorAddress);
        pool.setInterestWeightTranche(0, weightSr);
        pool.setInterestWeightTranche(1, weightJr);
        pool.setTreasuryWeights(weightTreasury, 10);
        vm.stopPrank();

        uint256 interestSr = uint256(interests) * weightSr / totalInterestWeight;
        uint256 interestJr = uint256(interests) * weightJr / totalInterestWeight;
        uint256 interestTreasury = interests - interestSr - interestJr;

        // Liquidity is non-zero and does not overflow after interests are paid.
        vm.assume(interestSr < type(uint128).max);
        vm.assume(interestJr < type(uint128).max);
        liquiditySr = uint128(bound(liquiditySr, 1, type(uint128).max - interestSr));
        liquidityJr = uint128(bound(liquidityJr, 1, type(uint128).max - interestJr));

        stdstore.target(address(pool)).sig(pool.realisedLiquidityOf.selector).with_key(address(srTranche)).checked_write(
            liquiditySr
        );
        stdstore.target(address(pool)).sig(pool.realisedLiquidityOf.selector).with_key(address(jrTranche)).checked_write(
            liquidityJr
        );

        pool.syncInterestsToLendingPool(interests);

        assertEq(pool.realisedLiquidityOf(address(srTranche)), liquiditySr + interestSr);
        assertEq(pool.realisedLiquidityOf(address(jrTranche)), liquidityJr + interestJr);
        assertEq(pool.realisedLiquidityOf(address(treasury)), interestTreasury);
        // We did not set initial totalRealisedLiquidity.
        assertEq(pool.totalRealisedLiquidity(), interests);
    }
}
