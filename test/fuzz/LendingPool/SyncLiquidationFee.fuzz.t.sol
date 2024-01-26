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
    function testFuzz_Success_syncLiquidationFee_MultipleTranches_NonZeroLiquidityJrTranche(
        uint128 penalty,
        uint8 weightTranche,
        uint8 weightTreasury,
        uint128 liquiditySr,
        uint128 liquidityJr
    ) public {
        uint256 totalPenaltyWeight = uint256(weightTranche) + weightTreasury;

        vm.startPrank(users.creatorAddress);
        pool.setLiquidationWeightTranche(weightTranche);
        pool.setTreasuryWeights(10, weightTreasury);
        vm.stopPrank();

        uint256 penaltyTranche;
        if (totalPenaltyWeight > 0) penaltyTranche = uint256(penalty) * weightTranche / totalPenaltyWeight;
        uint256 penaltyTreasury = penalty - penaltyTranche;

        // Liquidity Junior Tranche is non-zero and does not overflow after interests are paid.
        vm.assume(penaltyTranche < type(uint128).max);
        liquidityJr = uint128(bound(liquidityJr, 1, type(uint128).max - penaltyTranche));

        pool.setRealisedLiquidityOf(address(srTranche), liquiditySr);
        pool.setRealisedLiquidityOf(address(jrTranche), liquidityJr);

        pool.syncLiquidationFee(penalty);

        assertEq(pool.liquidityOf(address(srTranche)), liquiditySr);
        assertEq(pool.liquidityOf(address(jrTranche)), liquidityJr + penaltyTranche);
        assertEq(pool.liquidityOf(address(treasury)), penaltyTreasury);
    }

    function testFuzz_Success_syncLiquidationFee_MultipleTranches_ZeroLiquidityJrTranche(
        uint128 penalty,
        uint8 weightTranche,
        uint8 weightTreasury,
        uint128 liquiditySr
    ) public {
        vm.startPrank(users.creatorAddress);
        pool.setLiquidationWeightTranche(weightTranche);
        pool.setTreasuryWeights(10, weightTreasury);
        vm.stopPrank();

        pool.setRealisedLiquidityOf(address(srTranche), liquiditySr);

        pool.syncLiquidationFee(penalty);

        assertEq(pool.liquidityOf(address(srTranche)), liquiditySr);
        assertEq(pool.liquidityOf(address(jrTranche)), 0);
        assertEq(pool.liquidityOf(address(treasury)), penalty);
    }

    function testFuzz_Success_syncLiquidationFee_SingleTranches_NonZeroLiquidity(
        uint128 penalty,
        uint8 weightTranche,
        uint8 weightTreasury,
        uint128 liquiditySr
    ) public {
        uint256 totalPenaltyWeight = uint256(weightTranche) + weightTreasury;

        vm.startPrank(users.creatorAddress);
        pool.setLiquidationWeightTranche(weightTranche);
        pool.setTreasuryWeights(10, weightTreasury);
        vm.stopPrank();

        uint256 penaltyTranche;
        if (totalPenaltyWeight > 0) penaltyTranche = uint256(penalty) * weightTranche / totalPenaltyWeight;
        uint256 penaltyTreasury = penalty - penaltyTranche;

        vm.assume(penaltyTranche < type(uint128).max);
        liquiditySr = uint128(bound(liquiditySr, 1, type(uint128).max - penaltyTranche));

        pool.setRealisedLiquidityOf(address(srTranche), liquiditySr);

        pool.popTranche(1, address(jrTranche));

        pool.syncLiquidationFee(penalty);

        assertEq(pool.liquidityOf(address(srTranche)), liquiditySr + penaltyTranche);
        assertEq(pool.liquidityOf(address(jrTranche)), 0);
        assertEq(pool.liquidityOf(address(treasury)), penaltyTreasury);
    }

    function testFuzz_Success_syncLiquidationFee_SingleTranches_NonZeroLiquidity(
        uint128 penalty,
        uint8 weightTranche,
        uint8 weightTreasury
    ) public {
        vm.startPrank(users.creatorAddress);
        pool.setLiquidationWeightTranche(weightTranche);
        pool.setTreasuryWeights(10, weightTreasury);
        vm.stopPrank();

        pool.popTranche(1, address(jrTranche));

        pool.syncLiquidationFee(penalty);

        assertEq(pool.liquidityOf(address(srTranche)), 0);
        assertEq(pool.liquidityOf(address(jrTranche)), 0);
        assertEq(pool.liquidityOf(address(treasury)), penalty);
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

        assertEq(pool.liquidityOf(address(srTranche)), 0);
        assertEq(pool.liquidityOf(address(jrTranche)), 0);
        assertEq(pool.liquidityOf(address(treasury)), penalty);
    }
}
