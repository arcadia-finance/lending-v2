/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

import { AssetValuationLib } from "../../../lib/accounts-v2/src/libraries/AssetValuationLib.sol";

/**
 * @notice Fuzz tests for the function "totalLiquidity" of contract "LendingPool".
 */
contract TotalLiquidity_LendingPool_Fuzz_Test is LendingPool_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LendingPool_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_totalLiquidity(
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

        uint256 interest = calcUnrealisedDebtChecked(interestRate, deltaTimestamp, realisedDebt);
        uint256 expectedValue = initialLiquidity + interest;

        uint256 actualValue = pool.totalLiquidity();

        assertEq(actualValue, expectedValue);
    }
}
