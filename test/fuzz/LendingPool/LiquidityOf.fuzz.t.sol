/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

import { RiskConstants } from "../../../lib/accounts-v2/src/libraries/RiskConstants.sol";

/**
 * @notice Fuzz tests for the "liquidityOf" of contract "LendingPool".
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
        uint256 interestRate,
        uint24 deltaTimestamp,
        uint128 realisedDebt,
        uint120 initialLiquidity
    ) public {
        vm.assume(realisedDebt <= type(uint256).max / RiskConstants.RISK_VARIABLES_UNIT); // No overflow Risk Module
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
        if (interest * 100 < unrealisedDebt * 50) interest += 1;
        // interest for a tranche is rounded up
        uint256 expectedValue = initialLiquidity + interest;

        uint256 actualValue = pool.liquidityOf(address(srTranche));

        assertEq(actualValue, expectedValue);
    }
}
