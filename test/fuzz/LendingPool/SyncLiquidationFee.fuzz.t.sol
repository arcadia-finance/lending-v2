/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "syncLiquidationFee" of contract "LendingPool".
 */
contract SyncLiquidationFee_LendingPool_Fuzz_Test is LendingPool_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LendingPool_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_syncLiquidationFee_MultipleTranches(
        uint128 penalty,
        uint8 weightTranche,
        uint8 weightTreasury
    ) public {
        uint256 totalPenaltyWeight = uint256(weightTranche) + weightTreasury;

        vm.startPrank(users.creatorAddress);
        pool.setLiquidationWeightTranche(weightTranche);
        pool.setTreasuryWeights(10, weightTreasury);
        vm.stopPrank();

        pool.syncLiquidationFee(penalty);

        uint256 penaltyTranche;
        if (totalPenaltyWeight > 0) penaltyTranche = uint256(penalty) * weightTranche / totalPenaltyWeight;
        uint256 penaltyTreasury = penalty - penaltyTranche;

        assertEq(pool.realisedLiquidityOf(address(srTranche)), 0);
        assertEq(pool.realisedLiquidityOf(address(jrTranche)), penaltyTranche);
        assertEq(pool.realisedLiquidityOf(address(treasury)), penaltyTreasury);
    }

    function testFuzz_Success_syncLiquidationFee_SingleTranches(
        uint128 penalty,
        uint8 weightTranche,
        uint8 weightTreasury
    ) public {
        uint256 totalPenaltyWeight = uint256(weightTranche) + weightTreasury;

        vm.startPrank(users.creatorAddress);
        pool.setLiquidationWeightTranche(weightTranche);
        pool.setTreasuryWeights(10, weightTreasury);
        vm.stopPrank();

        pool.popTranche(1, address(jrTranche));

        pool.syncLiquidationFee(penalty);

        uint256 penaltyTranche;
        if (totalPenaltyWeight > 0) penaltyTranche = uint256(penalty) * weightTranche / totalPenaltyWeight;
        uint256 penaltyTreasury = penalty - penaltyTranche;

        assertEq(pool.realisedLiquidityOf(address(srTranche)), penaltyTranche);
        assertEq(pool.realisedLiquidityOf(address(jrTranche)), 0);
        assertEq(pool.realisedLiquidityOf(address(treasury)), penaltyTreasury);
    }

    function testFuzz_Success_syncLiquidationFee_NoTranches(uint128 penalty, uint8 weightTranche, uint8 weightTreasury)
        public
    {
        vm.startPrank(users.creatorAddress);
        pool.setLiquidationWeightTranche(weightTranche);
        pool.setTreasuryWeights(10, weightTreasury);
        vm.stopPrank();

        pool.popTranche(1, address(jrTranche));
        pool.popTranche(0, address(srTranche));

        pool.syncLiquidationFee(penalty);

        assertEq(pool.realisedLiquidityOf(address(srTranche)), 0);
        assertEq(pool.realisedLiquidityOf(address(jrTranche)), 0);
        assertEq(pool.realisedLiquidityOf(address(treasury)), penalty);
    }
}
