/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

import { AssetValuationLib } from "../../../lib/accounts-v2/src/libraries/AssetValuationLib.sol";

/**
 * @notice Fuzz tests for the function "totalAssets" of contract "LendingPool".
 */
contract TotalAssets_LendingPool_Fuzz_Test is LendingPool_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LendingPool_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_totalAssets(uint112 realisedDebt, uint80 interestRate, uint24 deltaTimestamp) public {
        // Given: collateralValue is smaller than maxExposure.
        realisedDebt = uint112(bound(realisedDebt, 0, type(uint112).max - 1));
        vm.assume(interestRate <= 1e3 * 1e18); // 1000%.
        vm.assume(interestRate > 0);
        vm.assume(deltaTimestamp <= 5 * 365 * 24 * 60 * 60); // 5 year.

        vm.prank(address(srTranche));
        pool.depositInLendingPool(type(uint128).max, users.liquidityProvider);

        depositTokenInAccount(proxyAccount, mockERC20.stable1, realisedDebt);

        vm.prank(users.accountOwner);
        pool.borrow(realisedDebt, address(proxyAccount), users.accountOwner, emptyBytes3);

        vm.prank(users.creatorAddress);
        pool.setInterestRate(interestRate);

        vm.warp(block.timestamp + deltaTimestamp);

        uint256 unrealisedDebt = calcUnrealisedDebtChecked(interestRate, deltaTimestamp, realisedDebt);
        uint256 expectedValue = realisedDebt + unrealisedDebt;

        uint256 actualValue = debt.totalAssets();

        assertEq(actualValue, expectedValue);
    }
}
