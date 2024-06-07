/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

import { AssetValuationLib } from "../../../lib/accounts-v2/src/libraries/AssetValuationLib.sol";

/**
 * @notice Fuzz tests for the function "liquidityOf" of contract "LendingPool".
 */
contract LiquidityOf_LendingPool_Fuzz_Test is LendingPool_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LendingPool_Fuzz_Test.setUp();

        vm.startPrank(users.owner);
        pool.setTreasuryWeights(0, 0);
        pool.setInterestWeightTranche(0, 0);
        pool.setInterestWeightTranche(1, 0);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_liquidityOf_Tranche(
        uint80 interestRate,
        uint24 deltaTimestamp,
        uint112 realisedDebt,
        uint120 initialLiquidity,
        uint16 interestWeightTranche,
        uint16 totalInterestWeight
    ) public {
        // Given interestWeights:
        totalInterestWeight = uint16(bound(totalInterestWeight, 1, type(uint16).max));
        interestWeightTranche = uint16(bound(interestWeightTranche, 0, totalInterestWeight));
        vm.startPrank(users.owner);
        pool.setInterestWeightTranche(0, interestWeightTranche);
        uint16 interestWeightTreasury = totalInterestWeight - interestWeightTranche;
        pool.setTreasuryWeights(interestWeightTreasury, 0);
        vm.stopPrank();

        // Given: collateralValue is smaller than maxExposure.
        realisedDebt = uint112(bound(realisedDebt, 1, type(uint112).max - 1));
        vm.assume(deltaTimestamp <= 5 * 365 * 24 * 60 * 60); // 5 year
        vm.assume(interestRate <= 1e3 * 10 ** 18); // 1000%
        vm.assume(interestRate > 0);
        vm.assume(initialLiquidity >= realisedDebt);

        vm.prank(address(srTranche));
        pool.depositInLendingPool(initialLiquidity, users.liquidityProvider);

        depositTokenInAccount(proxyAccount, mockERC20.stable1, realisedDebt);

        vm.prank(users.accountOwner);
        pool.borrow(realisedDebt, address(proxyAccount), users.accountOwner, emptyBytes3);

        vm.warp(block.timestamp + deltaTimestamp);

        vm.prank(users.owner);
        pool.setInterestRate(interestRate);

        uint256 unrealisedDebt = calcUnrealisedDebtChecked(interestRate, deltaTimestamp, realisedDebt);
        uint256 interest = unrealisedDebt * interestWeightTranche / totalInterestWeight;
        // interest for a tranche is rounded down
        uint256 expectedValue = initialLiquidity + interest;

        uint256 actualValue = pool.liquidityOf(address(srTranche));
        uint256 actualValue_ = pool.liquidityOfAndSync(address(srTranche));

        assertEq(actualValue, expectedValue);
        assertEq(actualValue, actualValue_);
    }

    function testFuzz_Success_liquidityOf_Treasury(
        uint80 interestRate,
        uint24 deltaTimestamp,
        uint112 realisedDebt,
        uint120 initialLiquidityTranche,
        uint120 initialLiquidityTreasury,
        uint16 interestWeightTreasury,
        uint16 totalInterestWeight
    ) public {
        // Given interestWeights:
        totalInterestWeight = uint16(bound(totalInterestWeight, 1, type(uint16).max));
        interestWeightTreasury = uint16(bound(interestWeightTreasury, 0, totalInterestWeight));
        vm.startPrank(users.owner);
        pool.setTreasuryWeights(interestWeightTreasury, 0);
        uint16 interestWeightTranche = totalInterestWeight - interestWeightTreasury;
        pool.setInterestWeightTranche(0, interestWeightTranche);
        vm.stopPrank();

        // Given: collateralValue is smaller than maxExposure.
        realisedDebt = uint112(bound(realisedDebt, 1, type(uint112).max - 1));
        vm.assume(deltaTimestamp <= 5 * 365 * 24 * 60 * 60); // 5 year
        vm.assume(interestRate <= 1e3 * 10 ** 18); // 1000%
        vm.assume(interestRate > 0);
        vm.assume(initialLiquidityTranche >= realisedDebt);
        vm.assume(initialLiquidityTranche >= 0);

        vm.prank(address(srTranche));
        pool.depositInLendingPool(initialLiquidityTranche, users.liquidityProvider);
        pool.setRealisedLiquidityOf(pool.getTreasury(), initialLiquidityTreasury);

        depositTokenInAccount(proxyAccount, mockERC20.stable1, realisedDebt);

        vm.prank(users.accountOwner);
        pool.borrow(realisedDebt, address(proxyAccount), users.accountOwner, emptyBytes3);

        vm.warp(block.timestamp + deltaTimestamp);

        vm.prank(users.owner);
        pool.setInterestRate(interestRate);

        uint256 unrealisedDebt = calcUnrealisedDebtChecked(interestRate, deltaTimestamp, realisedDebt);
        uint256 interest = unrealisedDebt * interestWeightTreasury / totalInterestWeight;
        // interest for a tranche is rounded down
        uint256 expectedValue = initialLiquidityTreasury + interest;

        uint256 actualValue = pool.liquidityOf(pool.getTreasury());
        uint256 actualValue_ = pool.liquidityOfAndSync(pool.getTreasury());

        assertEq(actualValue, expectedValue);
        // liquidityOf() the treasury will be slightly underestimated,
        // since all rounding errors of all tranches will go to the treasury.
        assertGe(actualValue_, actualValue);
        assertApproxEqAbs(actualValue_, actualValue, 10); //0.1% tolerance, rounding errors
    }

    function testFuzz_Success_liquidityOf_Other(
        address user,
        uint80 interestRate,
        uint24 deltaTimestamp,
        uint112 realisedDebt,
        uint120 initialLiquidityTranche,
        uint120 initialLiquidityUser,
        uint16 totalInterestWeight
    ) public {
        // Given: user does not earn interests.
        vm.assume(user != pool.getTreasury());
        vm.assume(user != address(srTranche));
        vm.assume(user != address(jrTranche));

        // Given interestWeights:
        totalInterestWeight = uint16(bound(totalInterestWeight, 1, type(uint16).max));
        vm.prank(users.owner);
        pool.setInterestWeightTranche(0, totalInterestWeight);

        // Given: collateralValue is smaller than maxExposure.
        realisedDebt = uint112(bound(realisedDebt, 1, type(uint112).max - 1));
        vm.assume(deltaTimestamp <= 5 * 365 * 24 * 60 * 60); // 5 year
        vm.assume(interestRate <= 1e3 * 10 ** 18); // 1000%
        vm.assume(interestRate > 0);
        vm.assume(initialLiquidityTranche >= realisedDebt);

        vm.prank(address(srTranche));
        pool.depositInLendingPool(initialLiquidityTranche, users.liquidityProvider);
        pool.setRealisedLiquidityOf(user, initialLiquidityUser);

        depositTokenInAccount(proxyAccount, mockERC20.stable1, realisedDebt);

        vm.prank(users.accountOwner);
        pool.borrow(realisedDebt, address(proxyAccount), users.accountOwner, emptyBytes3);

        vm.warp(block.timestamp + deltaTimestamp);

        vm.prank(users.owner);
        pool.setInterestRate(interestRate);

        uint256 actualValue = pool.liquidityOf(user);
        uint256 actualValue_ = pool.liquidityOfAndSync(user);

        assertEq(actualValue, initialLiquidityUser);
        assertEq(actualValue, actualValue_);
    }
}
