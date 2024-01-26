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
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_liquidityOf(
        uint80 interestRate,
        uint24 deltaTimestamp,
        uint112 realisedDebt,
        uint120 initialLiquidity
    ) public {
        // Given: collateralValue is smaller than maxExposure.
        realisedDebt = uint112(bound(realisedDebt, 0, type(uint112).max - 1));
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

        vm.prank(users.creatorAddress);
        pool.setInterestRate(interestRate);

        uint256 unrealisedDebt = calcUnrealisedDebtChecked(interestRate, deltaTimestamp, realisedDebt);
        uint256 interest = unrealisedDebt * 50 / 100;
        // interest for a tranche is rounded down
        uint256 expectedValue = initialLiquidity + interest;

        uint256 actualValue = pool.liquidityOf(address(srTranche));
        uint256 actualValue_ = pool.liquidityOfAndSync(address(srTranche));

        assertEq(actualValue, expectedValue);
        assertEq(actualValue, actualValue_);
    }
}
