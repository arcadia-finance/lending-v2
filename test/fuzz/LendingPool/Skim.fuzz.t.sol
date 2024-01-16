/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "skim" of contract "LendingPool".
 */
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
        vm.assume(auctionsInProgress_ > 0);
        pool.setAuctionsInProgress(auctionsInProgress_);

        vm.startPrank(sender);
        vm.expectRevert(AuctionOngoing.selector);
        pool.skim();
        vm.stopPrank();
    }

    function testFuzz_Success_skim(uint128 balanceOf, uint128 totalDebt, uint128 totalLiquidity, address sender)
        public
    {
        vm.assume(uint256(balanceOf) + totalDebt <= type(uint128).max);
        vm.assume(totalLiquidity <= balanceOf + totalDebt);

        pool.setTotalRealisedLiquidity(totalLiquidity);
        pool.setRealisedDebt(totalDebt);
        vm.prank(users.liquidityProvider);
        mockERC20.stable1.transfer(address(pool), balanceOf);

        vm.prank(sender);
        pool.skim();

        assertEq(pool.totalLiquidity(), balanceOf + totalDebt);
        assertEq(pool.liquidityOf(treasury), balanceOf + totalDebt - totalLiquidity);
    }
}
