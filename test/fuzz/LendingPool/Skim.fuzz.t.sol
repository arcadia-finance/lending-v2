/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

import { LendingPoolErrors } from "../../../src/libraries/Errors.sol";

/**
 * @notice Fuzz tests for the function "skim" of contract "LendingPool".
 */
// forge-lint: disable-next-item(unsafe-typecast)
contract Skim_LendingPool_Fuzz_Test is LendingPool_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LendingPool_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_skim_OngoingAuctions(uint16 auctionsInProgress_, address sender) public {
        auctionsInProgress_ = uint16(bound(auctionsInProgress_, 1, type(uint16).max));
        pool.setAuctionsInProgress(auctionsInProgress_);

        vm.startPrank(sender);
        vm.expectRevert(LendingPoolErrors.AuctionOngoing.selector);
        pool.skim();
        vm.stopPrank();
    }

    function testFuzz_Success_skim(uint128 balanceOf, uint128 totalDebt, uint128 totalLiquidity, address sender)
        public
    {
        totalDebt = uint128(bound(totalDebt, 0, type(uint128).max - balanceOf));
        totalLiquidity = uint128(bound(totalLiquidity, 0, balanceOf + totalDebt));

        pool.setTotalRealisedLiquidity(totalLiquidity);
        pool.setRealisedDebt(totalDebt);
        vm.prank(users.liquidityProvider);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        mockERC20.stable1.transfer(address(pool), balanceOf);

        vm.prank(sender);
        pool.skim();

        assertEq(pool.totalLiquidity(), balanceOf + totalDebt);
        assertEq(pool.liquidityOf(users.treasury), balanceOf + totalDebt - totalLiquidity);
    }
}
