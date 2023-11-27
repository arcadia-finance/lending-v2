/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "syncLiquidationFeeToLiquidityProviders" of contract "LendingPool".
 */
contract SyncLiquidationFeeToLiquidityProviders_LendingPool_Fuzz_Test is LendingPool_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LendingPool_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_syncLiquidationFeeToLiquidityProviders(
        uint128 penalty,
        uint8 weightSr,
        uint8 weightJr,
        uint8 weightTreasury
    ) public {
        uint256 totalPenaltyWeight = uint256(weightSr) + uint256(weightJr) + uint256(weightTreasury);
        vm.assume(totalPenaltyWeight > 0);
        vm.startPrank(users.creatorAddress);
        pool.setTrancheWeights(0, 10, weightSr);
        pool.setTrancheWeights(1, 10, weightJr);
        pool.setTreasuryWeights(10, weightTreasury);
        vm.stopPrank();

        pool.syncLiquidationFeeToLiquidityProviders(penalty);

        uint256 penaltySr = uint256(penalty) * weightSr / totalPenaltyWeight;
        uint256 penaltyJr = uint256(penalty) * weightJr / totalPenaltyWeight;
        uint256 penaltyTreasury = penalty - penaltySr - penaltyJr;

        assertEq(pool.realisedLiquidityOf(address(srTranche)), penaltySr);
        assertEq(pool.realisedLiquidityOf(address(jrTranche)), penaltyJr);
        assertEq(pool.realisedLiquidityOf(address(treasury)), penaltyTreasury);
    }
}
